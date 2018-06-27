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

// This tool filters out the -buildid args from any Go tool invocation when
// passed via -toolexec.

package main

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"syscall"
)

func main() {
	args := os.Args[1:]
	newArgs := make([]string, 0, len(args))
	for i := 0; i < len(args); i++ {
		arg := args[i]
		if arg == "-buildid" {
			i++
			continue
		}
		newArgs = append(newArgs, arg)
	}
	if runtime.GOOS == "windows" {
		cmd := exec.Command(newArgs[0], newArgs[1:]...)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			fmt.Println("error executing command %v: %v", newArgs[0], err)
			os.Exit(1)
		}
	} else {
		syscall.Exec(newArgs[0], newArgs, os.Environ())
	}
}
