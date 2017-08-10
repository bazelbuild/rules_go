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
	"strings"

	"github.com/bazelbuild/rules_go/go/tools/gazelle/config"
)

// structuredResolver resolves go_library labels within the same repository as
// the one of goPrefix.
type structuredResolver struct {
	l        Labeler
	goPrefix string
}

var _ Resolver = (*structuredResolver)(nil)

// Resolve takes a Go importpath within the same respository as r.goPrefix
// and resolves it into a label in Bazel.
func (r *structuredResolver) Resolve(importpath string) (Label, error) {
	if importpath == r.goPrefix {
		return Label{Name: config.DefaultLibName}, nil
	}

	prefix := r.goPrefix + "/"
	relImportpath := strings.TrimPrefix(importpath, prefix)
	if relImportpath == importpath {
		return Label{}, fmt.Errorf("importpath %q does not start with goPrefix %q", importpath, r.goPrefix)
	}

	return r.l.LibraryLabel(relImportpath), nil
}
