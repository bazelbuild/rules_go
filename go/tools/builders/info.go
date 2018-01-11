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

// info prints debugging information about the go environment.
// It is used to help examine the execution environment of rules_go
package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
)

const endOfHereDoc = "EndOfGoInfoReport"

func invoke(goenv *GoEnv, out *os.File, args []string) error {
	cmd := exec.Command(goenv.Go, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = append(os.Environ(), goenv.Env()...)
	if out != nil {
		cmd.Stdout = out
		cmd.Stderr = out
	}
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("error running %v: %v", args, err)
	}
	return nil
}

func run(args []string) error {
	filename := ""
	flags := flag.NewFlagSet("info", flag.ExitOnError)
	flags.StringVar(&filename, "out", filename, "The file to write the report to")
	goenv := envFlags(flags)
	if err := flags.Parse(args); err != nil {
		return err
	}
	if err := goenv.update(); err != nil {
		return err
	}
	f := os.Stderr
	if filename != "" {
		var err error
		f, err = os.Create(filename)
		if err != nil {
			return fmt.Errorf("Could not create report file: %v", err)
		}
		defer f.Close()
	}
	if err := invoke(goenv, f, []string{"version"}); err != nil {
		return err
	}
	if err := invoke(goenv, f, []string{"env"}); err != nil {
		return err
	}
	return nil
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}
