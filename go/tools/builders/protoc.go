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
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func run(args []string) error {
	// process the args
	options := multiFlag{}
	descriptors := multiFlag{}
	expected := multiFlag{}
	imports := multiFlag{}
	flags := flag.NewFlagSet("protoc", flag.ExitOnError)
	protoc := flags.String("protoc", "", "The path to the real protoc.")
	outPath := flags.String("out_path", "", "The base output path to write to.")
	plugin := flags.String("plugin", "", "The go plugin to use.")
	importpath := flags.String("importpath", "", "The importpath for the generated sources.")
	flags.Var(&options, "option", "The plugin options.")
	flags.Var(&descriptors, "descriptor_set", "The descriptor set to read.")
	flags.Var(&expected, "expected", "The expected output files.")
	flags.Var(&imports, "import", "Map a proto file to an import path.")
	if err := flags.Parse(args); err != nil {
		return err
	}
	plugin_base := filepath.Base(*plugin)
	plugin_name := strings.TrimPrefix(filepath.Base(*plugin), "protoc-gen-")
	options = append(options, fmt.Sprintf("import_path=%v", *importpath))
	for _, m := range imports {
		options = append(options, fmt.Sprintf("M%v", m))
	}
	protoc_args := []string{
		fmt.Sprintf("--%v_out=%v:%v", plugin_name, strings.Join(options, ","), *outPath),
		"--plugin", fmt.Sprintf("%v=%v", plugin_base, *plugin),
		"--descriptor_set_in", strings.Join(descriptors, ":"),
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
		missing := []string{}
		unexpected := []string{}
		filepath.Walk(".", func(path string, f os.FileInfo, err error) error {
			if strings.HasSuffix(path, ".pb.go") {
				wasExpected := false
				matches := []string{}
				base := filepath.Base(path)
				for _, s := range expected {
					if s == path {
						wasExpected = true
					}
					if base == filepath.Base(s) {
						matches = append(matches, s)
					}
				}
				if !wasExpected {
					if len(matches) != 1 {
						unexpected = append(unexpected, path)
					} else {
						// Unambiguous mapping to expected output, so copy it
						data, err := ioutil.ReadFile(path)
						if err != nil {
							return err
						}
						if err := ioutil.WriteFile(matches[0], data, 0644); err != nil {
							return err
						}
					}
				}
			}
			return nil
		})
		if len(missing) > 0 {
			return fmt.Errorf("protoc failed to make all outputs\nGot      %v\nExpected %v\nCheck that the go_package option is %q.", unexpected, missing, *importpath)
		}
	}
	return nil
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}
