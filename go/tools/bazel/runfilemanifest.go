// Copyright 2018 The Bazel Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package bazel

import (
	"bufio"
	"errors"
	"io"
	"path/filepath"
	"strings"
)

var errManifestInvalid = errors.New("runfiles manifest syntax error")

type manifestResolver map[string]string

// newManifestRunfilesResolver creates a new runfiles resolver that uses a manifest file to resolve
// filenames.
func newManifestRunfilesResolver(manifest io.Reader) (runfilesResolver, error) {
	resolver := manifestResolver{}
	scanner := bufio.NewScanner(manifest)

	for scanner.Scan() {
		a := strings.SplitN(scanner.Text(), " ", 2)
		if len(a) != 2 {
			return nil, errManifestInvalid
		}
		resolver[filepath.Clean(a[0])] = a[1]
	}

	return resolver, nil
}

// Resolve implements the Resolver interface.
func (r manifestResolver) Resolve(n string) (string, bool) {
	if fn, ok := r[filepath.Clean(n)]; ok {
		return fn, true
	}

	return "", false
}
