// Copyright 2019 The Bazel Authors. All rights reserved.
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
	"bufio"
	"fmt"
	"log"
	"os"
	"regexp"
	"strings"
)

func main() {
	log.SetFlags(0)
	log.SetPrefix("sanitize_patch_dates: ")
	if len(os.Args) == 1 {
		log.Fatalf("usage: sanitize_patch_dates *.patch")
	}
	for _, arg := range os.Args[1:] {
		if err := sanitize(arg); err != nil {
			log.Fatal(err)
		}
	}
}

var dateRegexp = regexp.MustCompile("20..-..-.. .*")

func sanitize(filename string) (err error) {
	r, err := os.Open(filename)
	if err != nil {
		return err
	}
	defer r.Close()

	tempFilename := filename + "~"
	w, err := os.Create(tempFilename)
	if err != nil {
		return err
	}
	defer func() {
		if w == nil {
			return
		}
		if cerr := w.Close(); err == nil && cerr != nil {
			err = cerr
		}
	}()

	s := bufio.NewScanner(r)
	for s.Scan() {
		line := s.Text()
		if strings.HasPrefix(line, "+++") || strings.HasPrefix(line, "---") {
			line = dateRegexp.ReplaceAllLiteralString(line, "2000-01-01 00:00:00.000000000 -0000")
		}
		if _, err := fmt.Fprintln(w, line); err != nil {
			return err
		}
	}
	if err := s.Err(); err != nil {
		return err
	}

	if err := w.Close(); err != nil {
		return err
	}
	w = nil
	if err := os.Rename(tempFilename, filename); err != nil {
		return err
	}
	return nil
}
