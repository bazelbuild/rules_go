// Copyright 2021 The Bazel Authors. All rights reserved.
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
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	dir := os.Args[1]
	files := os.Args[2:]
	if err := run(dir, files); err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	}
}

func run(dir string, files []string) error {
	for _, file := range files {
		path := filepath.Join(dir, file)
		if strings.HasSuffix(path, "/") {
			if err := os.MkdirAll(path, 0777); err != nil {
				return err
			}
		} else {
			if err := os.MkdirAll(filepath.Dir(path), 0777); err != nil {
				return err
			}
			if err := ioutil.WriteFile(path, nil, 0666); err != nil {
				return err
			}
		}
	}
	return nil
}
