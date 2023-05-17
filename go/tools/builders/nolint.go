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

import "strings"

type Linters []string

func (l Linters) Contains(s string) bool {
	if len(l) == 0 {
		return true
	}
	for _, name := range l {
		if s == name {
			return true
		}
	}
	return false
}

// From a comment like '//nolint:foo,bar' returns [foo, bar], true. If no
// comment is found, returns nil, false. For 'nolint:all' or 'nolint', returns
// nil, true.
func parseNolint(text string) (Linters, bool) {
	text = strings.TrimLeft(text, "/ ")
	if !strings.HasPrefix(text, "nolint") {
		return nil, false
	}
	parts := strings.Split(text, ":")
	if len(parts) == 1 {
		return nil, true
	}
	linters := strings.Split(parts[1], ",")
	for _, linter := range linters {
		if strings.EqualFold(linter, "all") {
			return nil, true
		}
	}
	return Linters(linters), true
}
