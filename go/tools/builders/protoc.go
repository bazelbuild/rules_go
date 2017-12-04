// Copyright 2017 The Bazel Authors. All rights reserved.
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

// protoc invokes the protobuf compiler and captures the resulting .pb.go file.
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func run(args []string) error {
	// process the args
	expected := multiFlag{}
	flags := flag.NewFlagSet("protoc", flag.ExitOnError)
	protoc := flags.String("protoc", "", "The path to the real protoc.")
	descriptor_set_in := flags.String("descriptor_set_in", "", "The descriptor set to read.")
	go_out := flags.String("go_out", "", "The go plugin options.")
	plugin := flags.String("plugin", "", "The go plugin to use.")
	importpath := flags.String("importpath", "", "The importpath for the generated sources.")
	flags.Var(&expected, "expected", "The expected output files.")
	if err := flags.Parse(args); err != nil {
		return err
	}
	protoc_args := []string{
		"--go_out", *go_out,
		"--plugin", *plugin,
		"--descriptor_set_in", *descriptor_set_in,
	}
	protoc_args = append(protoc_args, flags.Args()...)
	cmd := exec.Command(*protoc, protoc_args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("error running protoc: %v", err)
	}
	notFound := []string{}
	for _, src := range expected {
		if _, err := os.Stat(src); os.IsNotExist(err) {
			notFound = append(notFound, src)
		}
	}
	if len(notFound) > 0 {
		unexpected := []string{}
		filepath.Walk(".", func(path string, f os.FileInfo, err error) error {
			if strings.HasSuffix(path, ".pb.go") {
				wasExpected := false
				for _, s := range expected {
					if s == path {
						wasExpected = true
					}
				}
				if !wasExpected {
					unexpected = append(unexpected, path)
				}
			}
			return nil
		})
		return fmt.Errorf("protoc failed to make all outputs\nGot      %v\nExpected %v\nCheck that the go_package option is %q.", unexpected, notFound, *importpath)
	}
	return nil
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}
