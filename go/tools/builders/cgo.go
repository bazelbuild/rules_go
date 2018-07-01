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

// cgo invokes "go tool cgo" in two separate actions:
//
// * In _cgo_codegen, cgo filters source files and then generates .cgo1.go
//   and .cgo2.c files containing split definitions.
// * In _cgo_import, cgo generates _cgo_gotypes.go which contains type
//   information for C definitions.

package main

import (
	"errors"
	"flag"
	"fmt"
	"go/build"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"
	"unicode"
)

func run(args []string) error {
	builderArgs, toolArgs := splitArgs(args)
	sources := multiFlag{}
	importMode := false
	flags := flag.NewFlagSet("CGoCodeGen", flag.ExitOnError)
	goenv := envFlags(flags)
	flags.Var(&sources, "src", "A source file to be filtered and compiled")
	flags.BoolVar(&importMode, "import", false, "When true, run cgo in import mode.")
	// process the args
	if err := flags.Parse(builderArgs); err != nil {
		return err
	}
	if err := goenv.checkFlags(); err != nil {
		return err
	}

	// When running in import mode, just invoke cgo with the tool args. No need
	// to process source files.
	if importMode {
		dynpackage, err := extractPackage(sources[0])
		if err != nil {
			return err
		}
		goargs := goenv.goTool("cgo", "-dynpackage", dynpackage)
		goargs = append(goargs, toolArgs...)
		return goenv.runCommand(goargs)
	}

	// create a temporary directory. sources actually passed to cgo will be moved
	// here first so that we can use -srcdir to avoid very long mangled filenames.
	srcDir, err := ioutil.TempDir("", "srcdir")
	if err != nil {
		return err
	}
	defer os.RemoveAll(srcDir)

	// apply build constraints to the source list
	// also pick out the cgo sources
	cgoSrcs := []string{}
	cgoOuts := []string{}
	cgoCOuts := []string{}
	objDirs := make(map[string]bool)
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
		metadata, err := readGoMetadata(build.Default, in, true)
		if err != nil {
			return err
		}
		// if this is not a go file, it cannot be cgo, so just check the filter
		if !strings.HasSuffix(in, ".go") {
			// Not a go file, just filter, assume C or C-like
			if metadata.matched {
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

		if !metadata.matched {
			if metadata.pkg == "" {
				return fmt.Errorf("%s: error: could not parse package name", in)
			}
			// filtered file, fake both the go and the c
			if err := ioutil.WriteFile(out, []byte("package "+metadata.pkg), 0644); err != nil {
				return err
			}
			if err := ioutil.WriteFile(cOut, []byte(""), 0644); err != nil {
				return err
			}
			continue
		}

		if pkgName != "" && metadata.pkg != pkgName {
			return fmt.Errorf("multiple packages found: %s and %s", pkgName, metadata.pkg)
		}
		pkgName = metadata.pkg

		if metadata.isCgo {
			// add to cgo file list
			srcInBase := strings.TrimSuffix(filepath.Base(out), ".cgo1.go") + ".go"
			srcIn := filepath.Join(srcDir, srcInBase)
			if err := ioutil.WriteFile(srcIn, data, 0644); err != nil {
				return err
			}
			cgoSrcs = append(cgoSrcs, srcInBase)
			cgoOuts = append(cgoOuts, out)
			cgoCOuts = append(cgoCOuts, cOut)
			objDirs[filepath.Dir(out)] = true
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
		nullCgoBase := "_cgo_empty.go"
		nullCgo := filepath.Join(srcDir, nullCgoBase)
		if err := ioutil.WriteFile(nullCgo, []byte("package "+pkgName+"\n/*\n*/\nimport \"C\"\n"), 0644); err != nil {
			return err
		}
		cgoSrcs = append(cgoSrcs, nullCgoBase)
	}

	// Tokenize arguments to the C compiler. go_library.copts may contain
	// multiple options in the same string. Rules are expected to apply Bourne
	// shell tokenization to these, respecting quotes. Ideally, this would
	// be done in Skylark, but there's no API, and here, we can just copy what
	// go/build does.
	var ccArgs []string
	toolArgs, ccArgs = splitArgs(toolArgs)
	ccArgsSplit := make([]string, 0, len(ccArgs))
	for _, s := range ccArgs {
		if r, err := splitQuoted(s); err != nil {
			return fmt.Errorf("error tokenizing argument to C compiler: %s: %v:", s, err)
		} else {
			ccArgsSplit = append(ccArgsSplit, r...)
		}
	}

	// Run cgo.
	goargs := goenv.goTool("cgo", "-srcdir", srcDir)
	goargs = append(goargs, toolArgs...)
	goargs = append(goargs, "--")
	goargs = append(goargs, ccArgsSplit...)
	goargs = append(goargs, cgoSrcs...)
	if err := goenv.runCommand(goargs); err != nil {
		return err
	}

	// Now we fix up the generated files
	for _, src := range cgoOuts {
		if err := fixupLineComments(src, abs("."), false); err != nil {
			return err
		}
	}
	for _, src := range cgoCOuts {
		if err := fixupLineComments(src, srcDir, true); err != nil {
			return err
		}
	}
	for objDir, _ := range objDirs {
		if err := fixupLineComments(filepath.Join(objDir, "_cgo_export.h"), srcDir, true); err != nil {
			return err
		}
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

// removes the srcDir prefix from //line or #line comments to make source files reproducible
func fixupLineComments(filename, srcDir string, cFile bool) error {
	const goFileLinePrefix = "//line "
	const cFileLinePrefix = "#line "
	goFileTrim := goFileLinePrefix + srcDir
	body, err := ioutil.ReadFile(filename)
	if err != nil {
		return err
	}
	lines := strings.Split(string(body), "\n")
	for i, line := range lines {
		if cFile {
			if strings.HasPrefix(line, cFileLinePrefix) {
				lines[i] = strings.Replace(line, srcDir, "", 1)
			}
		} else {
			if strings.HasPrefix(line, goFileTrim) {
				lines[i] = goFileLinePrefix + line[len(goFileTrim)+1:]
			}
		}
	}
	if err := ioutil.WriteFile(filename, []byte(strings.Join(lines, "\n")), 0666); err != nil {
		return err
	}
	return nil
}

func main() {
	log.SetPrefix("CgoCodegen: ")
	log.SetFlags(0) // don't print timestamps
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}
