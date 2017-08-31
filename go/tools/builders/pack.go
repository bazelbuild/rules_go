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

// pack copies an .a file and appends a list of .o files to the copy using
// go tool pack. It is invoked by the Go rules as an action.
package main

import (
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
)

func run(args []string) error {
	if len(args) < 4 {
		return fmt.Errorf("Usage: pack gotool in.a out.a obj.o...")
	}
	gotool := args[0]
	inArchive := args[1]
	outArchive := args[2]
	objects := args[3:]

	if err := copyFile(inArchive, outArchive); err != nil {
		return err
	}
	packArgs := append([]string{"tool", "pack", "r", outArchive}, objects...)
	cmd := exec.Command(gotool, packArgs...)
	return cmd.Run()
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}

func copyFile(inPath, outPath string) error {
	inFile, err := os.Open(inPath)
	if err != nil {
		return err
	}
	defer inFile.Close()
	outFile, err := os.Create(outPath)
	if err != nil {
		return err
	}
	defer outFile.Close()
	_, err = io.Copy(outFile, inFile)
	return err
}
