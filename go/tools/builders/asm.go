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

// asm builds a single .s file with "go tool asm". It is invoked by the
// Go rules as an action.
package main

import (
	"encoding/json"
	"fmt"
	"go/build"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

type params struct {
	// Path to the "go" binary in the Go toolchain.
	GoTool string `json:"go_tool"`

	// List of directories that may contain headers included by the source.
	Includes []string `json:"includes"`

	// The Go assembly source file to build.
	Source string `json:"source"`

	// Path to the .o file that the assembler should write.
	Out string `json:"out"`
}

func run(p params) error {
	goRoot := filepath.Dir(filepath.Dir(p.GoTool))
	if err := os.Setenv("GOROOT", goRoot); err != nil {
		return fmt.Errorf("error setting environment: %v", err)
	}

	bctx := build.Default
	bctx.CgoEnabled = true

	var source string
	if match, err := matchFile(bctx, p.Source); err != nil {
		return fmt.Errorf("error applying constraints: %v", err)
	} else if match {
		source = p.Source
	} else {
		source = os.DevNull
	}

	outDir := filepath.Dir(p.Out)
	if err := os.MkdirAll(outDir, 0600); err != nil {
		return fmt.Errorf("error creating output directory: %v", err)
	}

	args := []string{"tool", "asm"}
	for _, d := range p.Includes {
		args = append(args, "-I", d)
	}
	args = append(args, "-o", p.Out, source)
	cmd := exec.Command(p.GoTool, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("error running assembler: %v", err)
	}

	return nil
}

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintf(os.Stderr, "usage: %s params\n", os.Args[0])
		os.Exit(1)
	}

	paramsData := []byte(os.Args[1])
	var p params
	if err := json.Unmarshal(paramsData, &p); err != nil {
		log.Fatalf("error parsing params file: %v", err)
	}

	if err := run(p); err != nil {
		log.Fatal(err)
	}
}
