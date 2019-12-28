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

// gendefs takes a list of .go files containing C package names and generates
// .go files with the C package names replaced by real values and types in Go
// syntax.

package main

import (
	"flag"
	"log"
	"os"
	"path/filepath"
)

func main() {
	if err := run(os.Args); err != nil {
		log.Fatal(err)
	}
}

func run(args []string) error {
	fs := flag.NewFlagSet("GoGendefs", flag.ExitOnError)
	goenv := envFlags(fs)
	var srcs, hdrs, outs multiFlag
	fs.Var(&hdrs, "hdr", "A C header file containing C package definitions")
	// Assumption: src and o input args come in ordered pairs
	// e.g. "-src src1.go -o out1.go -src src2.go -o out2.go"
	fs.Var(&srcs, "src", "A Go source file containing C package names")
	fs.Var(&outs, "o", "A output path for the generated Go source")
	if err := fs.Parse(args[1:]); err != nil {
		return err
	}
	if err := goenv.checkFlags(); err != nil {
		return err
	}
	for i := range srcs {
		srcs[i] = abs(srcs[i])
	}
	for i := range hdrs {
		hdrs[i] = abs(hdrs[i])
	}
	for i := range outs {
		outs[i] = abs(outs[i])
	}

	if err := generateGodefs(goenv, srcs, hdrs, outs); err != nil {
		return err
	}

	return nil
}

func generateGodefs(goenv *env, srcs, hdrs, outs []string) error {
	workDir, cleanup, err := goenv.workDir()
	if err != nil {
		return err
	}
	defer cleanup()

	hdrDirs := map[string]bool{}
	var hdrIncludes []string
	for _, hdr := range hdrs {
		hdrDir := filepath.Dir(hdr)
		if !hdrDirs[hdrDir] {
			hdrDirs[hdrDir] = true
			hdrIncludes = append(hdrIncludes, "-iquote", hdrDir)
		}
	}

	for i, src := range srcs {
		out := outs[i]
		f, err := os.Create(out)
		if err != nil {
			return err
		}
		defer f.Close()

		srcDir := filepath.Dir(src)
		src = filepath.Base(src)
		cmd := goenv.goTool("cgo", "-srcdir", srcDir, "-objdir", workDir, "-godefs")
		cmd = append(cmd, "--")
		cmd = append(cmd, hdrIncludes...)
		cmd = append(cmd, src)
		if err := goenv.runCommandToFile(f, cmd); err != nil {
			return err
		}
	}

	return nil
}
