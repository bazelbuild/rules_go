/* Copyright 2016 The Bazel Authors. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package lib_test

import (
	"flag"
	"testing"

	"github.com/bazelbuild/rules_go/examples/lib"
)

var (
	buildTimeWant = flag.String("lib_test.buildtime", "", "expected value in TestBuildTime")
)

func TestLibraryPkgPath(t *testing.T) {
	if got, want := lib.PkgPath(), "github.com/bazelbuild/rules_go/examples/lib"; got != want {
		t.Errorf("lib.PkgPath() = %q; want %q", got, want)
	}
}

func TestBuildTime(t *testing.T) {
	if got, want := lib.BuildTime(), *buildTimeWant; got != want {
		t.Errorf("buildTime = %q; want %q", got, want)
	}
}
