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
	"os/exec"
	"path/filepath"
	"strings"
)

var (
	cgo  = flag.Bool("cgo", false, "Sets whether cgo-using files are allowed to pass the filter.")
	tags = flag.String("tags", "", "Only pass through files that match these tags.")

	absMarker    = "-abs-"
	filterMarker = "-filter-"
	escapeMarker = "-escape-"
)

// runCommand goes through it's arguments filtering out source code files that do not match
// the supplied build context, and expanding the current working directory where needed.
// It then invokes the executable with the remaining result.
func runCommand(bctx build.Context, executable string, input []string) error {
	var err error
	args := []string{}
	unfiltered := 0
	filtered := 0
	for _, in := range input {
		if strings.HasPrefix(in, escapeMarker) {
			// do no processing except to strip the escaping
			args = append(args, in[len(escapeMarker):])
			continue
		}
		abs := false
		filter := false
		if strings.HasPrefix(in, absMarker) {
			in = in[len(absMarker):]
			abs = true
		}
		if strings.HasPrefix(in, filterMarker) {
			in = in[len(filterMarker):]
			filter = true
		}
		if abs {
			in, err = filepath.Abs(in)
			if err != nil {
				return err
			}
		}
		if filter {
			dir, base := filepath.Split(in)
			matches, err := bctx.MatchFile(dir, base)
			if err != nil {
				//match test failure, return it
				return err
			}
			if !matches {
				// file should be filtered
				filtered++
				continue
			}
			unfiltered++
		}
		// entry has not been filtered
		args = append(args, in)
	}
	// args should now be filtered
	// if all possible filter candidates were removed, then don't run the command
	if filtered > 0 && unfiltered == 0 {
		return fmt.Errorf("All %d candidate(s) were filtered", filtered)
	}
	// if we get here, we want to run the command itself
	cmd := exec.Command(executable, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func main() {
	flag.Parse()

	bctx := build.Default
	bctx.BuildTags = strings.Split(*tags, ",")
	bctx.CgoEnabled = *cgo

	args := flag.Args()
	if len(args) <= 0 {
		log.Fatal("filter_exec needs a command to run")
	}
	if err := runCommand(bctx, args[0], args[1:]); err != nil {
		log.Fatalf("filter_exec error: %v\n", err)
	}
}
