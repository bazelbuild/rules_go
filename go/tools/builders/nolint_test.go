// Copyright 2023 The Bazel Authors. All rights reserved.
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

package main

import (
	"reflect"
	"testing"
)

func TestParseNolint(t *testing.T) {
	assert := func(text string, linters map[string]bool, valid bool) {
		result, ok := parseNolint(text)
		if valid != ok {
			t.Fatalf("parseNolint expect %t got %t", valid, ok)
		}
		if !reflect.DeepEqual(result, linters) {
			t.Fatalf("parseNolint expect %v got %v", linters, result)
		}
	}

	assert("not a comment", nil, false)
	assert("// comment", nil, false)
	assert("//nolint", nil, true)
	assert("//nolint:all", nil, true)
	assert("// nolint:foo", map[string]bool{"foo": true}, true)
	assert(
		"// nolint:foo,bar,baz",
		map[string]bool{
			"foo": true,
			"bar": true,
			"baz": true,
		},
		true,
	)
}
