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

// compile compiles .go files with "go tool compile". It is invoked by the
// Go rules as an action.
package main

import (
	"fmt"
	"go/build"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

func run(args []string) error {
	// process the args
	if len(args) < 2 {
		return fmt.Errorf("Usage: compile gotool [sources] -- <extra options>")
	}
	gotool := args[0]
	args = args[1:]
	sources := []string{}
	goopts := []string{}
	bctx := build.Default
	bctx.CgoEnabled = true
	for i, s := range args {
		if s == "--" {
			goopts = args[i+1:]
			break
		}
		sources = append(sources, s)
	}
	// apply build constraints to the source list
	sources, err := filterFiles(bctx, sources)
	if err != nil {
		return err
	}
	if len(sources) <= 0 {
		return fmt.Errorf("no unfiltered sources to compile")
	}
	// Now we need to abs include and trim paths
	needAbs := false
	for i, arg := range goopts {
		switch {
		case needAbs:
			needAbs = false
			abs, err := filepath.Abs(arg)
			if err == nil {
				goopts[i] = abs
			}
		case arg == "-I":
			needAbs = true
		case arg == "-trimpath":
			needAbs = true
		default:
			needAbs = false
		}
	}

	goargs := append([]string{"tool", "compile"}, goopts...)
	goargs = append(goargs, sources...)
	cmd := exec.Command(gotool, goargs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("error running compiler: %v", err)
	}
	return nil
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}
