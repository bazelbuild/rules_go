// Copyright 2020 The Bazel Authors. All rights reserved.
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

package main

import (
	"flag"
	"io"
	"os"
)

// Concat replaces the "cat * > out" pattern without requiring a shell and works
// on all platforms.
func concat(args []string) error {
	var out string
	flags := flag.NewFlagSet("concat", flag.ExitOnError)
	flags.StringVar(&out, "out", "", "output file or directory")
	if err := flags.Parse(args); err != nil {
		return err
	}

	outFile, err := os.Create(out)
	if err != nil {
		return err
	}
	defer outFile.Close()

	for _, f := range flags.Args() {
		inFile, err := os.Open(f)
		if err != nil {
			return err
		}
		_, err = io.Copy(outFile, inFile)
		inFile.Close() // close the file anyway
		if err != nil {
			return err
		}
	}

	return err
}
