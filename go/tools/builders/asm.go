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
	"flag"
	"fmt"
	"go/build"
	"log"
	"os"
)

func run(args []string) error {
	// Parse arguments.
	builderArgs, toolArgs := splitArgs(args)
	flags := flag.NewFlagSet("GoAsm", flag.ExitOnError)
	goenv := envFlags(flags)
	if err := flags.Parse(builderArgs); err != nil {
		return err
	}
	if err := goenv.checkFlags(); err != nil {
		return err
	}
	if flags.NArg() != 1 {
		return fmt.Errorf("wanted exactly 1 source file; got %d", flags.NArg())
	}
	source := flags.Args()[0]

	// Filter the input file.
	metadata, err := readGoMetadata(build.Default, source, false)
	if err != nil {
		return err
	}
	if !metadata.matched {
		source = os.DevNull
	}

	// Build source with the assembler.
	goargs := goenv.goTool("asm", toolArgs...)
	goargs = append(goargs, source)
	absArgs(goargs, []string{"-I", "-o", "-trimpath"})
	return goenv.runCommand(goargs)
}

func main() {
	log.SetFlags(0)
	log.SetPrefix("GoAsm: ")
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}
