/* Copyright 2016 The Bazel Authors. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package main

import (
	"flag"
	"fmt"
	"go/build"
	"log"
	"os"
	"path/filepath"
	"strings"
)

var (
	cgo   = flag.Bool("cgo", false, "Sets whether cgo-using files are allowed to pass the filter.")
	quiet = flag.Bool("quiet", false, "Don't print filenames. Return code will be 0 if any files pass the filter.")
	tags  = flag.String("tags", "", "Only pass through files that match these tags.")
)

// Returns an array of strings containing only the filenames that should build
// according to the Context given.
func filterFilenames(bctx build.Context, inputs []string) ([]string, error) {
	outputs := []string{}

	for _, filename := range inputs {
		fullPath, err := filepath.Abs(filename)
		if err != nil {
			return nil, err
		}
		dir, base := filepath.Split(fullPath)

		matches, err := bctx.MatchFile(dir, base)
		if err != nil {
			return nil, err
		}

		if matches {
			outputs = append(outputs, filename)
		}
	}
	return outputs, nil
}

func main() {
	flag.Parse()

	bctx := build.Default
	bctx.BuildTags = strings.Split(*tags, ",")
	bctx.CgoEnabled = *cgo

	filenames, err := filterFilenames(bctx, flag.Args())
	if err != nil {
		log.Fatalf("build_tags error: %v\n", err)
	}

	if !*quiet {
		for _, filename := range filenames {
			fmt.Println(filename)
		}
	}
	if len(filenames) == 0 {
		os.Exit(1)
	}
}
