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
	"bytes"
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type FileInfo struct {
	Base       string    // The basename of the path
	Path       string    // The full path to the final file
	Expected   bool      // Whether the file is expected by the rules
	Created    bool      // Whether the file was created by protoc
	From       *FileInfo // The actual file protoc produced if not Path
	Unique     bool      // True if this base name is unique in expected results
	Ambiguious bool      // True if there were more than one possible outputs that matched this file
}

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
	pluginBase := filepath.Base(*plugin)
	pluginName := strings.TrimPrefix(filepath.Base(*plugin), "protoc-gen-")
	options = append(options, fmt.Sprintf("import_path=%v", *importpath))
	for _, m := range imports {
		options = append(options, fmt.Sprintf("M%v", m))
	}
	protoc_args := []string{
		fmt.Sprintf("--%v_out=%v:%v", pluginName, strings.Join(options, ","), *outPath),
		"--plugin", fmt.Sprintf("%v=%v", pluginBase, *plugin),
		"--descriptor_set_in", strings.Join(descriptors, ":"),
	}
	protoc_args = append(protoc_args, flags.Args()...)
	cmd := exec.Command(*protoc, protoc_args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("error running protoc: %v", err)
	}
	// Build our file map, and test for existance
	files := map[string]*FileInfo{}
	byBase := map[string]*FileInfo{}
	for _, path := range expected {
		info := &FileInfo{
			Path:     path,
			Base:     filepath.Base(path),
			Expected: true,
			Unique:   true,
		}
		files[info.Path] = info
		if byBase[info.Base] != nil {
			info.Unique = false
			byBase[info.Base].Unique = false
		} else {
			byBase[info.Base] = info
		}
	}
	// Walk the generated files
	filepath.Walk(".", func(path string, f os.FileInfo, err error) error {
		if !strings.HasSuffix(path, ".pb.go") {
			return nil
		}
		info := files[path]
		if info != nil {
			info.Created = true
			return nil
		}
		info = &FileInfo{
			Path:    path,
			Base:    filepath.Base(path),
			Created: true,
		}
		files[path] = info
		copyTo := byBase[info.Base]
		switch {
		case copyTo == nil:
			// Unwanted output
		case !copyTo.Unique:
			// not unique, no copy allowed
		case info.From != nil:
			copyTo.Ambiguious = true
			info.Ambiguious = true
		default:
			copyTo.From = info
			copyTo.Created = true
			info.Expected = true
		}
		return nil
	})
	buf := &bytes.Buffer{}
	for _, f := range files {
		switch {
		case f.Expected && !f.Created:
			fmt.Fprintf(buf, "Failed to create %v.\n", f.Path)
		case f.Expected && f.Ambiguious:
			fmt.Fprintf(buf, "Ambiguious output %v.\n", f.Path)
		case f.From != nil:
			data, err := ioutil.ReadFile(f.From.Path)
			if err != nil {
				return err
			}
			if err := ioutil.WriteFile(f.Path, data, 0644); err != nil {
				return err
			}
		case !f.Expected:
			fmt.Fprintf(buf, "Unexpected output %v.\n", f.Path)
		}
		if buf.Len() > 0 {
			fmt.Fprintf(buf, "Check that the go_package option is %q.", *importpath)
			return errors.New(buf.String())
		}
	}
	return nil
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}
