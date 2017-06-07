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
	"fmt"
	"go/build"
	"log"
	"os"
	"os/exec"
)

func run(args []string) error {
	// process the args
	if len(args) < 3 || args[2] != "--" {
		return fmt.Errorf("Usage: asm gotool source.s -- <extra options>")
	}
	gotool := args[0]
	source := args[1]
	// filter our input file list
	bctx := build.Default
	bctx.CgoEnabled = true
	matched, err := matchFile(bctx, source)
	if err != nil {
		return err
	}
	if !matched {
		source = os.DevNull
	}
	goargs := []string{"tool", "asm"}
	goargs = append(goargs, args[3:]...)
	goargs = append(goargs, source)
	cmd := exec.Command(gotool, goargs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("error running assembler: %v", err)
	}
	return nil
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}
