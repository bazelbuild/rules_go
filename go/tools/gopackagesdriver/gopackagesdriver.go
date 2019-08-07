// Copyright 2019 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// gopackagesdriver collects metadata, syntax, and type information for
// Go packages built with bazel. It implements the driver interface for
// golang.org/x/tools/go/packages. When gopackagesdriver is installed
// in PATH, tools like gopls written with golang.org/x/tools/go/packages,
// work in bazel workspaces.
package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"go/types"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"sort"

	bespb "github.com/bazelbuild/rules_go/go/tools/gopackagesdriver/proto/build_event_stream"
	"github.com/golang/protobuf/proto"
	"golang.org/x/tools/go/packages"
)

func main() {
	log.SetPrefix("gopackagesdriver: ")
	log.SetFlags(0)
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}

// driverRequest is a JSON object sent by golang.org/x/tools/go/packages
// on stdin. Keep in sync.
type driverRequest struct {
	Command    string            `json:"command"`
	Mode       packages.LoadMode `json:"mode"`
	Env        []string          `json:"env"`
	BuildFlags []string          `json:"build_flags"`
	Tests      bool              `json:"tests"`
	Overlay    map[string][]byte `json:"overlay"`
}

// driverResponse is a JSON object sent by this program to
// golang.org/x/tools/go/packages on stdout. Keep in sync.
type driverResponse struct {
	// Sizes, if not nil, is the types.Sizes to use when type checking.
	Sizes *types.StdSizes

	// Roots is the set of package IDs that make up the root packages.
	// We have to encode this separately because when we encode a single package
	// we cannot know if it is one of the roots as that requires knowledge of the
	// graph it is part of.
	Roots []string `json:",omitempty"`

	// Packages is the full set of packages in the graph.
	// The packages are not connected into a graph.
	// The Imports if populated will be stubs that only have their ID set.
	// Imports will be connected and then type and syntax information added in a
	// later pass (see refine).
	Packages []*packages.Package
}

func run(args []string) error {
	// Parse command line arguments and driver request sent on stdin.
	fs := flag.NewFlagSet("gopackagesdriver", flag.ExitOnError)
	if err := fs.Parse(args); err != nil {
		return err
	}
	targets := fs.Args()
	if len(targets) == 0 {
		return errors.New("no targets specified")
	}

	reqData, err := ioutil.ReadAll(os.Stdin)
	if err != nil {
		return err
	}
	var req driverRequest
	if err := json.Unmarshal(reqData, &req); err != nil {
		return fmt.Errorf("could not unmarshal driver request: %v", err)
	}

	// Build package data files using bazel. We use one of several aspects
	// (depending on what mode we're in). The aspect produces .json and source
	// files in an output group. Each .json file contains a serialized
	// *packages.Package object.
	outputGroup := "gopackagesdriver_data"
	aspect := "gopackagesdriver_todo"

	// We ask bazel to write build event protos to a binary file, which
	// we read to find the output files.
	eventFile, err := ioutil.TempFile("", "gopackagesdriver-bazel-bep-*.bin")
	if err != nil {
		return err
	}
	eventFileName := eventFile.Name()
	defer func() {
		if eventFile != nil {
			eventFile.Close()
		}
		os.Remove(eventFileName)
	}()

	cmd := exec.Command("bazel", "build")
	cmd.Args = append(cmd.Args, "--aspects="+aspect)
	cmd.Args = append(cmd.Args, "--output_groups="+outputGroup)
	cmd.Args = append(cmd.Args, "--build_event_binary_file="+eventFile.Name())
	cmd.Args = append(cmd.Args, req.BuildFlags...)
	cmd.Args = append(cmd.Args, "--")
	for _, target := range targets {
		cmd.Args = append(cmd.Args, target)
	}
	cmd.Stdout = os.Stderr // sic
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("error running bazel: %v", err)
	}

	eventData, err := ioutil.ReadAll(eventFile)
	if err != nil {
		return fmt.Errorf("could not read bazel build event file: %v", err)
	}
	eventFile.Close()

	var rootSets []string
	setToFiles := make(map[string][]string)
	setToSets := make(map[string][]string)
	pbuf := proto.NewBuffer(eventData)
	var event bespb.BuildEvent
	for !event.GetLastMessage() {
		if err := pbuf.DecodeMessage(&event); err != nil {
			return err
		}

		if id := event.GetId().GetTargetCompleted(); id != nil {
			completed := event.GetCompleted()
			if !completed.GetSuccess() {
				return fmt.Errorf("%s: target did not build successfully", id.GetLabel())
			}
			for _, g := range completed.GetOutputGroup() {
				for _, s := range g.GetFileSets() {
					if setId := s.GetId(); setId != "" {
						rootSets = append(rootSets, setId)
					}
				}
			}
		}

		if id := event.GetId().GetNamedSet(); id != nil {
			files := event.GetNamedSetOfFiles().GetFiles()
			fileNames := make([]string, len(files))
			for i, f := range files {
				fileNames[i] = f.GetName()
			}
			setToFiles[id.GetId()] = fileNames
			sets := event.GetNamedSetOfFiles().GetFileSets()
			setIds := make([]string, len(sets))
			for i, s := range sets {
				setIds[i] = s.GetId()
			}
			setToSets[id.GetId()] = setIds
			continue
		}
	}

	var visit func(string, map[string]bool, map[string]bool)
	visit = func(setId string, files map[string]bool, visited map[string]bool) {
		if visited[setId] {
			return
		}
		visited[setId] = true
		for _, f := range setToFiles[setId] {
			files[f] = true
		}
		for _, s := range setToSets[setId] {
			visit(s, files, visited)
		}
	}

	files := make(map[string]bool)
	for _, s := range rootSets {
		visit(s, files, map[string]bool{})
	}
	sortedFiles := make([]string, 0, len(files))
	for f := range files {
		sortedFiles = append(sortedFiles, f)
	}
	sort.Strings(sortedFiles)

	// Load data files referenced on the command line.
	pkgs := make(map[string]*packages.Package)
	roots := make(map[string]bool)
	for _, target := range targets {
		panic(fmt.Sprintf("json processing not implemented: %s", target))
	}

	sortedRoots := make([]string, 0, len(roots))
	for root := range roots {
		sortedRoots = append(sortedRoots, root)
	}
	sort.Strings(sortedRoots)

	sortedPkgs := make([]*packages.Package, 0, len(pkgs))
	for _, pkg := range pkgs {
		sortedPkgs = append(sortedPkgs, pkg)
	}
	sort.Slice(sortedPkgs, func(i, j int) bool {
		return sortedPkgs[i].ID < sortedPkgs[j].ID
	})

	resp := driverResponse{
		Sizes:    nil, // TODO
		Roots:    sortedRoots,
		Packages: sortedPkgs,
	}
	respData, err := json.Marshal(resp)
	if err != nil {
		return fmt.Errorf("could not marshal driver response: %v", err)
	}
	_, err = os.Stdout.Write(respData)
	if err != nil {
		return err
	}

	return errors.New("not implemented")
}
