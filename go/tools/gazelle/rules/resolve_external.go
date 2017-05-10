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

package rules

import (
	"path"
	"strings"

	"golang.org/x/tools/go/vcs"
)

var (
	// repoRootForImportPath is overwritten only in unit test to avoid depending on
	// network communication.
	repoRootForImportPath = vcs.RepoRootForImportPath
)

// ImportPathToBazelRepoName converts a Go import path into a bazel repo name
// following the guidelines in http://bazel.io/docs/be/functions.html#workspace
func ImportPathToBazelRepoName(importpath string) string {
	components := strings.Split(importpath, "/")
	labels := strings.Split(components[0], ".")
	var reversed []string
	for i := range labels {
		l := labels[len(labels)-i-1]
		reversed = append(reversed, l)
	}
	repo := strings.Join(append(reversed, components[1:]...), "_")
	return strings.NewReplacer("-", "_", ".", "_").Replace(repo)
}

type externalResolver struct{}

// resolve resolves "importpath" into a label, assuming that it is a label in an
// external repository. It also assumes that the external repository follows the
// recommended reverse-DNS form of workspace name as described in
// http://bazel.io/docs/be/functions.html#workspace.
func (e externalResolver) resolve(importpath, dir string) (label, error) {
	prefix := findCachedRepoRoot(importpath)
	if prefix == "" {
		r, err := repoRootForImportPath(importpath, false)
		if err != nil {
			return label{}, err
		}
		prefix = r.Root
		repoRootCache[prefix] = 0
	}

	var pkg string
	if importpath != prefix {
		pkg = strings.TrimPrefix(importpath, prefix+"/")
	}

	return label{
		repo: ImportPathToBazelRepoName(prefix),
		pkg:  pkg,
		name: defaultLibName,
	}, nil
}

func findCachedRepoRoot(importpath string) string {
	// subpaths contains slices of importpath with components removed. For
	// example:
	//   golang.org/x/tools/go/vcs
	//   golang.org/x/tools/go
	//   golang.org/x/tools
	subpaths := []string{importpath}

	for {
		if n, ok := repoRootCache[importpath]; ok {
			if n >= len(subpaths) {
				// The import path is shorter than expected. Treat as a miss.
				return ""
			}
			// Cache hit. Restore n components of the import path to get the
			// repository root.
			return subpaths[len(subpaths)-n-1]
		}

		// Prefix not found. Remove the last component and try again.
		importpath = path.Dir(importpath)
		if importpath == "." || importpath == "/" {
			// Cache miss.
			return ""
		}
		subpaths = append(subpaths, importpath)
	}
}

// repoCache is a map of known repo prefixes to the number of additional
// path components needed to form the repo root. For example, for the key
// "golang.org/x", the value is 1, since one additional component is needed
// to form a full repository path (for example, "golang.org/x/net").
//
// This is initially populated by a set of well-known servers, but
// externalResolver.resolve will add entries as it looks up new packages.
var repoRootCache map[string]int

// resetRepoRootCache creates repoRootCache and adds special cases. It is
// called during initialization and in tests.
func resetRepoRootCache() {
	repoRootCache = map[string]int{
		"golang.org/x":      1,
		"google.golang.org": 1,
		"cloud.google.com":  1,
		"github.com":        2,
	}
}

func init() {
	resetRepoRootCache()
}
