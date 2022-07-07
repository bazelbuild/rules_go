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
	"flag"
	"fmt"
	"go/build"
	"io/ioutil"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
)

// asm builds a single .s file with "go tool asm". It is invoked by the
// Go rules as an action.
func asm(args []string) error {
	// Parse arguments.
	args, _, err := expandParamsFiles(args)
	if err != nil {
		return err
	}
	builderArgs, asmFlags := splitArgs(args)
	var outPath string
	flags := flag.NewFlagSet("GoAsm", flag.ExitOnError)
	flags.StringVar(&outPath, "o", "", "The output archive file to write")
	goenv := envFlags(flags)
	if err := flags.Parse(builderArgs); err != nil {
		return err
	}
	if err := goenv.checkFlags(); err != nil {
		return err
	}
	if flags.NArg() != 1 {
		return fmt.Errorf("wanted exactly 1 source file; got %d", flags.NArg())
	}
	source := flags.Args()[0]

	// Filter the input file.
	metadata, err := readFileInfo(build.Default, source)
	if err != nil {
		return err
	}
	if !metadata.matched {
		source = os.DevNull
	}

	// Build source with the assembler.
	// Note: As of Go 1.19, this would require a valid package path to work.
	// But since this functionality is only used by the deprecated action API,
	// we won't fix this.
	return asmFile(goenv, source, "", asmFlags, outPath)
}

// buildSymabisFile generates a file from assembly files that is consumed
// by the compiler. This is only needed in go1.12+ when there is at least one
// .s file. If the symabis file is not needed, no file will be generated,
// and "", nil will be returned.
func buildSymabisFile(goenv *env, sFiles, hFiles []fileInfo, asmhdr string) (string, error) {
	if len(sFiles) == 0 {
		return "", nil
	}

	// Check version. The symabis file is only required and can only be built
	// starting at go1.12.
	version := runtime.Version()
	if strings.HasPrefix(version, "go1.") {
		minor := version[len("go1."):]
		if i := strings.IndexByte(minor, '.'); i >= 0 {
			minor = minor[:i]
		}
		n, err := strconv.Atoi(minor)
		if err == nil && n <= 11 {
			return "", nil
		}
		// Fall through if the version can't be parsed. It's probably a newer
		// development version.
	}

	// Create an empty go_asm.h file. The compiler will write this later, but
	// we need one to exist now.
	asmhdrFile, err := os.Create(asmhdr)
	if err != nil {
		return "", err
	}
	if err := asmhdrFile.Close(); err != nil {
		return "", err
	}
	asmhdrDir := filepath.Dir(asmhdr)

	// Create a temporary output file. The caller is responsible for deleting it.
	var symabisName string
	symabisFile, err := ioutil.TempFile("", "symabis")
	if err != nil {
		return "", err
	}
	symabisName = symabisFile.Name()
	symabisFile.Close()

	// Run the assembler.
	wd, err := os.Getwd()
	if err != nil {
		return symabisName, err
	}
	asmargs := goenv.goTool("asm")
	asmargs = append(asmargs, "-trimpath", wd)
	asmargs = append(asmargs, "-I", wd)
	asmargs = append(asmargs, "-I", filepath.Join(os.Getenv("GOROOT"), "pkg", "include"))
	asmargs = append(asmargs, "-I", asmhdrDir)
	seenHdrDirs := map[string]bool{wd: true, asmhdrDir: true}
	for _, hFile := range hFiles {
		hdrDir := filepath.Dir(abs(hFile.filename))
		if !seenHdrDirs[hdrDir] {
			asmargs = append(asmargs, "-I", hdrDir)
			seenHdrDirs[hdrDir] = true
		}
	}
	// TODO(#1894): define GOOS_goos, GOARCH_goarch, both here and in the
	// GoAsm action.
	asmargs = append(asmargs, "-gensymabis", "-o", symabisName, "--")
	for _, sFile := range sFiles {
		asmargs = append(asmargs, sFile.filename)
	}

	err = goenv.runCommand(asmargs)
	return symabisName, err
}

func asmFile(goenv *env, srcPath, packagePath string, asmFlags []string, outPath string) error {
	args := goenv.goTool("asm")
	args = append(args, asmFlags...)
	// The package path has to be specified as of Go 1.19 or the resulting
	// object will be unlinkable, but the -p flag is also only available
	// since Go 1.19.
	if packagePath != "" && isGo119OrHigher() {
		args = append(args, "-p", packagePath)
	}
	args = append(args, "-trimpath", ".")
	args = append(args, "-o", outPath)
	args = append(args, "--", srcPath)
	absArgs(args, []string{"-I", "-o", "-trimpath"})
	return goenv.runCommand(args)
}

var goMinorVersionRegexp = regexp.MustCompile(`^go1\.(\d+)`)

func isGo119OrHigher() bool {
	match := goMinorVersionRegexp.FindStringSubmatch(runtime.Version())
	if match == nil {
		// Developer version or something with an unparseable version string,
		// assume Go 1.19 or higher.
		return true
	}
	minorVersion, err := strconv.Atoi(match[1])
	if err != nil {
		return true
	}
	return minorVersion >= 19
}
