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
	"os"
	"os/signal"
	"runtime/debug"
	"syscall"
)

func RegisterTimeoutHandler() {
	go func() {
		// When the Bazel test timeout is reached, Bazel sends a SIGTERM. We
		// panic just like native go test would so that the user gets stack
		// traces of all running go routines.
		// See https://github.com/golang/go/blob/e816eb50140841c524fd07ecb4eaa078954eb47c/src/testing/testing.go#L2351
		c := make(chan os.Signal, 1)
		signal.Notify(c, syscall.SIGTERM)
		<-c
		debug.SetTraceback("all")
		panic("test timed out")
	}()
}
