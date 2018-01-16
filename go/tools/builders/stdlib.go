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
	"log"
	"os"
	"os/exec"
)

func install_stdlib(goenv *GoEnv, target string, args []string) error {
	args = append(args, target)
	env := os.Environ()
	env = append(env, goenv.Env()...)
	cmd := exec.Command(goenv.Go, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = env
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("error running go install %s: %v", target, err)
	}
	return nil
}

func run(args []string) error {
	// process the args
	flags := flag.NewFlagSet("stdlib", flag.ExitOnError)
	goenv := envFlags(flags)
	out := flags.String("out", "", "Path to output go root")
	race := flags.Bool("race", false, "Build in race mode")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if err := goenv.update(); err != nil {
		return err
	}
	goroot := goenv.rootPath
	output := abs(*out)
	// Link in the bare minimum needed to the new GOROOT
	if err := replicate(goroot, output, replicatePaths("src", "pkg/tool", "pkg/include")); err != nil {
		return err
	}
	// Now switch to the newly created GOROOT
	goenv.rootPath = output
	// Run the commands needed to build the std library in the right mode
	installArgs := []string{"install", "-asmflags", "-trimpath " + abs(".")}
	if *race {
		installArgs = append(installArgs, "-race")
	}
	if err := install_stdlib(goenv, "std", installArgs); err != nil {
		return err
	}
	if err := install_stdlib(goenv, "runtime/cgo", installArgs); err != nil {
		return err
	}
	return nil
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}
