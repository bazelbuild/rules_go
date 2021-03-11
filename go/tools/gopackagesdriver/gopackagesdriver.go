// Copyright 2021 The Bazel Go Rules Authors. All rights reserved.
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

// gopackagesdriver collects metadata, syntax, and type information for
// Go packages built with bazel. It implements the driver interface for
// golang.org/x/tools/go/packages. When gopackagesdriver is installed
// in PATH, tools like gopls written with golang.org/x/tools/go/packages,
// work in bazel workspaces.
package main

import (
	"io"
	"log"
	"os"

	"github.com/bazelbuild/rules_go/go/tools/gopackagesdriver/bazelquerydriver"
	"github.com/bazelbuild/rules_go/go/tools/gopackagesdriver/protocol"
)

func main() {
	cleanup := func() error { return nil }
	if logfile := os.Getenv("GOPACKAGESDRIVER_LOGFILE"); logfile != "" {
		f, err := os.OpenFile(logfile, os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)
		if err != nil {
			log.Fatalf("couldn't open log file: %s", err)
		}
		errorWriter := io.MultiWriter(f, os.Stderr)
		cleanup = f.Close
		log.SetOutput(errorWriter)
		log.SetFlags(log.Lshortfile | log.Ldate | log.Ltime)
	}

	defer cleanup()

	protocol.Run(bazelquerydriver.LoadPackages)
}
