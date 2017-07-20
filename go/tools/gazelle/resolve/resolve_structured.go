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

package resolve

import (
	"fmt"
	"path"
	"strings"
)

// structuredResolver resolves go_library labels within the same repository as
// the one of goPrefix.
type structuredResolver struct {
	goPrefix string
}

// Resolve takes a Go importpath within the same respository as r.goPrefix
// and resolves it into a label in Bazel.
func (r structuredResolver) Resolve(importpath, dir string) (Label, error) {
	if isRelative(importpath) {
		importpath = path.Clean(path.Join(r.goPrefix, dir, importpath))
	}

	if importpath == r.goPrefix {
		return Label{Name: DefaultLibName}, nil
	}

	if prefix := r.goPrefix + "/"; strings.HasPrefix(importpath, prefix) {
		pkg := strings.TrimPrefix(importpath, prefix)
		if pkg == dir {
			return Label{Name: DefaultLibName, Relative: true}, nil
		}
		return Label{Pkg: pkg, Name: DefaultLibName}, nil
	}

	return Label{}, fmt.Errorf("importpath %q does not start with goPrefix %q", importpath, r.goPrefix)
}
