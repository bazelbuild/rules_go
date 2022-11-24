// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"fmt"
	"io/ioutil"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

func main() {
	path, err := runfiles.Rlocation("io_bazel_rules_go/tests/runfiles/test.txt")
	if err != nil {
		panic(err)
	}
	b, err := ioutil.ReadFile(path)
	if err != nil {
		panic(err)
	}
	fmt.Println(string(b))
}
