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

// md5sum replicates the equivalent functionality of the unix tool of the same name.
package main

import (
	"crypto/md5"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
)

func md5SumFile(filename string) ([]byte, error) {
	var result []byte
	f, err := os.Open(filename)
	if err != nil {
		return result, err
	}
	defer f.Close()
	hash := md5.New()
	if _, err := io.Copy(hash, f); err != nil {
		return nil, err
	}
	return hash.Sum(result), nil
}

func run(args []string) error {
	// Prepare our flags
	flags := flag.NewFlagSet("md5sum", flag.ExitOnError)
	output := flags.String("output", "", "If set, write the results to this file, instead of stdout.")
	if err := flags.Parse(args); err != nil {
		return err
	}
	// print the outputs if we need not
	to := os.Stdout
	if *output != "" {
		f, err := os.Create(*output)
		if err != nil {
			return err
		}
		defer f.Close()
		to = f
	}
	for _, path := range flags.Args() {
		walkFn := func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}
			if info.IsDir() {
				return nil
			}

			if b, err := md5SumFile(path); err != nil {
				return err
			} else {
				fmt.Fprintf(to, "%s  %x\n", path, b)
			}
			return nil
		}

		if err := filepath.Walk(path, walkFn); err != nil {
			return err
		}
	}
	return nil
}

func main() {
	log.SetFlags(0)
	log.SetPrefix("GoMd5sum: ")
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}
