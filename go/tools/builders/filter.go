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

package main

import (
	"go/build"
	"path/filepath"
)

// filterFiles applies build constraints to a list of input files. It returns
// list of input files that should be compiled.
func filterFiles(bctx build.Context, inputs []string) ([]string, error) {
	var outputs []string
	for _, input := range inputs {
		if match, err := matchFile(bctx, input); err != nil {
			return nil, err
		} else if match {
			outputs = append(outputs, input)
		}
	}
	return outputs, nil
}

// matchFile applies build constraints to an input file and returns whether
// it should be compiled.
// TODO(#70): cross compilation: support GOOS, GOARCH that are different
// from the host platform.
func matchFile(bctx build.Context, input string) (bool, error) {
	dir, base := filepath.Split(input)
	return bctx.MatchFile(dir, base)
}
