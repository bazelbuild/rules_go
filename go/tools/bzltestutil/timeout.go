// Copyright 2020 The Bazel Authors. All rights reserved.
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

package bzltestutil

import (
	"fmt"
	"os"
	"os/signal"
	"runtime"
	"syscall"
)

func RegisterTimeoutHandler() {
	// When the Bazel test timeout is reached, Bazel sends a SIGTERM. We print stack traces for all
	// goroutines just like native go test would. We do not panic (like native go test does) because
	// users may legitimately want to use SIGTERM in tests and prints are less disruptive than
	// panics in that case.
	// See https://github.com/golang/go/blob/e816eb50140841c524fd07ecb4eaa078954eb47c/src/testing/testing.go#L2351
	c := make(chan os.Signal, 1)
	signal.Notify(c, syscall.SIGTERM)
	go func() {
		<-c
		buf := make([]byte, 1<<24)
		stacklen := runtime.Stack(buf, true)
		fmt.Printf("Received SIGTERM, printing stack traces of all goroutines:\n%s", buf[:stacklen])
	}()
}
