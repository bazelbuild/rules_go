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
	"os"
	"path/filepath"
	"strings"
)

// GoEnv holds the go environment as specified on the command line.
type GoEnv struct {
	// Go is the path to the go executable.
	Go string
	// Verbose debugging print control
	Verbose      bool
	rootFile     string
	rootPath     string
	cgo          bool
	compilerPath string
	goos         string
	goarch       string
	tags         string
	cc           string
	cpp_flags    multiFlag
	ld_flags     multiFlag
}

func abs(path string) string {
	if abs, err := filepath.Abs(path); err != nil {
		return path
	} else {
		return abs
	}
}

func envFlags(flags *flag.FlagSet) *GoEnv {
	env := &GoEnv{}
	flags.StringVar(&env.Go, "go", "", "The path to the go tool.")
	flags.StringVar(&env.rootFile, "root_file", "", "The go root file to use.")
	flags.BoolVar(&env.cgo, "cgo", false, "The value for CGO_ENABLED.")
	flags.StringVar(&env.compilerPath, "compiler_path", "", "The value for PATH.")
	flags.StringVar(&env.goos, "goos", "", "The value for GOOS.")
	flags.StringVar(&env.goarch, "goarch", "", "The value for GOARCH.")
	flags.BoolVar(&env.Verbose, "v", false, "Enables verbose debugging prints.")
	flags.StringVar(&env.tags, "tags", "", "Only pass through files that match these tags.")
	flags.StringVar(&env.cc, "cc", "", "Sets the c compiler to use")
	flags.Var(&env.cpp_flags, "cpp_flag", "An entry to add to the c compiler flags")
	flags.Var(&env.ld_flags, "ld_flag", "An entry to add to the c linker flags")
	return env
}

func (env *GoEnv) update() error {
	if env.rootFile != "" {
		env.rootFile = abs(env.rootFile)
		env.rootPath = env.rootFile
		if s, err := os.Stat(env.rootFile); err == nil {
			if !s.IsDir() {
				env.rootPath = filepath.Dir(env.rootFile)
			}
		}
	}
	if env.compilerPath != "" {
		env.compilerPath = abs(env.compilerPath)
	}
	return nil
}

func (env *GoEnv) Env() []string {
	cgoEnabled := "0"
	if env.cgo {
		cgoEnabled = "1"
	}
	result := []string{
		fmt.Sprintf("GOROOT=%s", env.rootPath),
		"GOROOT_FINAL=GOROOT",
		fmt.Sprintf("GOOS=%s", env.goos),
		fmt.Sprintf("GOARCH=%s", env.goarch),
		fmt.Sprintf("CGO_ENABLED=%s", cgoEnabled),
		fmt.Sprintf("PATH=%s", env.compilerPath),
		fmt.Sprintf("COMPILER_PATH=%s", env.compilerPath),
	}
	if env.cc != "" {
		cc := abs(env.cc)
		result = append(result,
			fmt.Sprintf("CC=%s", cc),
			fmt.Sprintf("CXX=%s", cc),
		)
	}
	if len(env.cpp_flags) > 0 {
		result = append(result,
			fmt.Sprintf("CGO_CPPFLAGS=%s", strings.Join(env.cpp_flags, " ")),
		)
	}
	if len(env.ld_flags) > 0 {
		result = append(result,
			fmt.Sprintf("CGO_LDFLAGS=%s", strings.Join(env.ld_flags, " ")),
		)
	}
	return result
}

func (env *GoEnv) BuildContext() build.Context {
	bctx := build.Default
	bctx.GOROOT = env.rootPath
	bctx.GOOS = env.goos
	bctx.GOARCH = env.goarch
	bctx.CgoEnabled = env.cgo
	bctx.BuildTags = strings.Split(env.tags, ",")
	return bctx
}
