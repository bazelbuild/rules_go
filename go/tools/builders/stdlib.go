// Copyright 2018 The Bazel Authors. All rights reserved.
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

// stdlib builds the standard library in the appropriate mode into a new goroot.
package main

import (
	"flag"
	"fmt"
	"go/build"
	"log"
	"os"
	"strings"
)

func run(args []string) error {
	// process the args
	flags := flag.NewFlagSet("stdlib", flag.ExitOnError)
	goenv := envFlags(flags)
	filterBuildid := flags.String("filter_buildid", "", "Path to filter_buildid tool")
	out := flags.String("out", "", "Path to output go root")
	race := flags.Bool("race", false, "Build in race mode")
	shared := flags.Bool("shared", false, "Build in shared mode")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if err := goenv.checkFlags(); err != nil {
		return err
	}
	goroot := os.Getenv("GOROOT")
	if goroot == "" {
		return fmt.Errorf("GOROOT not set")
	}
	output := abs(*out)

	// Link in the bare minimum needed to the new GOROOT
	if err := replicate(goroot, output, replicatePaths("src", "pkg/tool", "pkg/include")); err != nil {
		return err
	}

	// Now switch to the newly created GOROOT
	os.Setenv("GOROOT", output)

	// Make sure we have an absolute path to the C compiler.
	// TODO(#1357): also take absolute paths of includes and other paths in flags.
	os.Setenv("CC", abs(os.Getenv("CC")))

	// Build the commands needed to build the std library in the right mode
	installArgs := []string{"install", "-toolexec", abs(*filterBuildid)}
	if len(build.Default.BuildTags) > 0 {
		installArgs = append(installArgs, "-tags", strings.Join(build.Default.BuildTags, ","))
	}
	gcflags := []string{}
	ldflags := []string{"-trimpath", abs(".")}
	asmflags := []string{"-trimpath", abs(".")}
	if *race {
		installArgs = append(installArgs, "-race")
	}
	if *shared {
		gcflags = append(gcflags, "-shared")
		ldflags = append(ldflags, "-shared")
		asmflags = append(asmflags, "-shared")
	}

	// Since Go 1.10, an all= prefix indicates the flags should apply to the package
	// and its dependencies, rather than just the package itself. This was the
	// default behavior before Go 1.10.
	allSlug := ""
	for _, t := range build.Default.ReleaseTags {
		if t == "go1.10" {
			allSlug = "all="
			break
		}
	}
	installArgs = append(installArgs, "-gcflags="+allSlug+strings.Join(gcflags, " "))
	installArgs = append(installArgs, "-ldflags="+allSlug+strings.Join(ldflags, " "))
	installArgs = append(installArgs, "-asmflags="+allSlug+strings.Join(asmflags, " "))

	for _, target := range []string{"std", "runtime/cgo"} {
		if err := goenv.runGoCommand(append(installArgs, target)); err != nil {
			return err
		}
	}
	return nil
}

func main() {
	log.SetFlags(0)
	log.SetPrefix("GoStdlib: ")
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}
