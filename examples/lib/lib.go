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

package lib

import (
	"reflect"

	"github.com/bazelbuild/rules_go/examples/lib/deep"
)

var buildTime string

// Meaning returns the meaning of Life, the Universe and Everything.
func Meaning() int {
	return deep.Thought()
}

type dummy struct{}

// PkgPath returns the package importpath of this package.
func PkgPath() string {
	return reflect.TypeOf(dummy{}).PkgPath()
}

// BuildTime returns the buildTime which should be replaced with -X flag.
func BuildTime() string {
	return buildTime
}
