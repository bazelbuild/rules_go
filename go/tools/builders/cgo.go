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

// cgo invokes "go tool cgo" after filtering souces, and then process the output
// into a normalised form. It is invoked by the Go rules as an action.
package main

import (
	"errors"
	"flag"
	"fmt"
	"go/ast"
	"go/build"
	"go/parser"
	"go/token"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"unicode"
)

func testCgo(src string, data []byte) (bool, string, error) {
	fset := token.NewFileSet()
	parsed, err := parser.ParseFile(fset, src, data, parser.ImportsOnly)
	if err != nil {
		return false, "", err
	}
	for _, decl := range parsed.Decls {
		d, ok := decl.(*ast.GenDecl)
		if !ok {
			continue
		}
		for _, dspec := range d.Specs {
			spec, ok := dspec.(*ast.ImportSpec)
			if !ok {
				continue
			}
			imp, err := strconv.Unquote(spec.Path.Value)
			if err != nil {
				log.Panicf("%s: invalid string `%s`", src, spec.Path.Value)
			}
			if imp == "C" {
				return true, parsed.Name.String(), nil
			}
		}
	}
	return false, parsed.Name.String(), nil
}

func run(args []string) error {
	sources := multiFlag{}
	cc := ""
	objdir := ""
	flags := flag.NewFlagSet("cgo", flag.ContinueOnError)
	flags.Var(&sources, "src", "A source file to be filtered and compiled")
	flags.StringVar(&cc, "cc", "", "Sets the c compiler to use")
	flags.StringVar(&objdir, "objdir", "", "The output directory")
	// process the args
	if len(args) < 2 {
		flags.Usage()
		return fmt.Errorf("The go tool must be specified")
	}
	gotool := args[0]
	if err := flags.Parse(args[1:]); err != nil {
		return err
	}

	// apply build constraints to the source list
	// also pick out the cgo sources
	bctx := build.Default
	bctx.CgoEnabled = true
	cgoSrcs := []string{}
	pkgName := ""
	for _, s := range sources {
		bits := strings.SplitN(s, "=", 2)
		if len(bits) != 2 {
			return fmt.Errorf("Invalid source arg, expected output=input got %s", s)
		}
		out := bits[0]
		in := bits[1]
		// Check if the file is filtered first
		data, err := ioutil.ReadFile(in)
		if err != nil {
			return err
		}
		match, err := matchFile(bctx, in)
		if err != nil {
			return err
		}
		// if this is not a go file, it cannot be cgo, so just check the filter
		if !strings.HasSuffix(in, ".go") {
			// Not a go file, just filter, assume C or C-like
			if match {
				// not filtered, copy over
				if err := ioutil.WriteFile(out, data, 0644); err != nil {
					return err
				}
			} else {
				// filtered, make empty file
				if err := ioutil.WriteFile(out, []byte(""), 0644); err != nil {
					return err
				}
			}
			continue
		}

		// Go source, must produce both c and go outputs
		cOut := strings.TrimSuffix(out, ".cgo1.go") + ".cgo2.c"
		isCgo, pkg, err := testCgo(in, data)
		if err != nil {
			return err
		}
		if pkg == "" {
			return fmt.Errorf("%s: error: could not parse package name", in)
		}

		if !match {
			// filtered file, fake both the go and the c
			if err := ioutil.WriteFile(out, []byte("package "+pkg), 0644); err != nil {
				return err
			}
			if err := ioutil.WriteFile(cOut, []byte(""), 0644); err != nil {
				return err
			}
			continue
		}

		if pkgName != "" && pkg != pkgName {
			return fmt.Errorf("multiple packages found: %s and %s", pkgName, pkg)
		}
		pkgName = pkg

		if isCgo {
			// add to cgo file list
			cgoSrcs = append(cgoSrcs, in)
		} else {
			// Non cgo file, copy the go and fake the c
			if err := ioutil.WriteFile(out, data, 0644); err != nil {
				return err
			}
			if err := ioutil.WriteFile(cOut, []byte(""), 0644); err != nil {
				return err
			}
		}
	}
	if pkgName == "" {
		return fmt.Errorf("no buildable Go source files found")
	}

	if len(cgoSrcs) == 0 {
		// If there were no cgo sources present, generate a minimal cgo input
		// This is so we can still run the cgo tool to build all the other outputs
		nullCgo := filepath.Join(objdir, "_cgo_empty.go")
		cgoSrcs = append(cgoSrcs, nullCgo)
		if err := ioutil.WriteFile(nullCgo, []byte("package "+pkgName+"\n/*\n*/\nimport \"C\"\n"), 0644); err != nil {
			return err
		}
	}

	// Tokenize copts. cc_library does this automatically, but cgo does not,
	// so we need to do it here.
	var copts []string
	for _, arg := range flags.Args() {
		args, err := splitQuoted(arg)
		if err != nil {
			return err
		}
		copts = append(copts, args...)
	}

	// Add the absoulute path to the c compiler to the environment
	if abs, err := filepath.Abs(cc); err == nil {
		cc = abs
	}
	env := os.Environ()
	env = append(env, fmt.Sprintf("CC=%s", cc))
	env = append(env, fmt.Sprintf("CXX=%s", cc))

	goargs := []string{"tool", "cgo", "-objdir", objdir}
	goargs = append(goargs, copts...)
	goargs = append(goargs, cgoSrcs...)
	cmd := exec.Command(gotool, goargs...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = env
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("error running cgo: %v", err)
	}
	return nil
}

// Copied from go/build.splitQuoted. Also in Gazelle (where tests are).
func splitQuoted(s string) (r []string, err error) {
	var args []string
	arg := make([]rune, len(s))
	escaped := false
	quoted := false
	quote := '\x00'
	i := 0
	for _, rune := range s {
		switch {
		case escaped:
			escaped = false
		case rune == '\\':
			escaped = true
			continue
		case quote != '\x00':
			if rune == quote {
				quote = '\x00'
				continue
			}
		case rune == '"' || rune == '\'':
			quoted = true
			quote = rune
			continue
		case unicode.IsSpace(rune):
			if quoted || i > 0 {
				quoted = false
				args = append(args, string(arg[:i]))
				i = 0
			}
			continue
		}
		arg[i] = rune
		i++
	}
	if quoted || i > 0 {
		args = append(args, string(arg[:i]))
	}
	if quote != 0 {
		err = errors.New("unclosed quote")
	} else if escaped {
		err = errors.New("unfinished escaping")
	}
	return args, err
}

func main() {
	log.SetPrefix("CgoCodegen: ")
	log.SetFlags(0) // don't print timestamps
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}
