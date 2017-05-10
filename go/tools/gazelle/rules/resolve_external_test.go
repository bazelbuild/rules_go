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
	"reflect"
	"strings"
	"testing"

	"golang.org/x/tools/go/vcs"
)

type special struct {
	in, want string
}

func TestSpecialCases(t *testing.T) {
	resetRepoRootCache()
	for _, c := range []special{
		{"golang.org/x/net/context", "golang.org/x/net"},
		{"golang.org/x/tools/go/vcs", "golang.org/x/tools"},
		{"golang.org/x/goimports", "golang.org/x/goimports"},
		{"cloud.google.com/fashion/industry", "cloud.google.com/fashion"},
		{"github.com/foo", ""},
		{"github.com/foo/bar", "github.com/foo/bar"},
		{"github.com/foo/bar/baz", "github.com/foo/bar"},
		{"unsupported.org/x/net/context", ""},
	} {
		if got := findCachedRepoRoot(c.in); got != c.want {
			t.Errorf("specialCases(%q) = %q; want %q", c.in, got, c.want)
		}
	}
}

func TestExternalResolver(t *testing.T) {
	repoRootForImportPath = stubRepoRootForImportPath
	resetRepoRootCache()

	var r externalResolver
	for _, spec := range []struct {
		importpath string
		want       label
	}{
		{
			importpath: "example.com/repo",
			want: label{
				repo: "com_example_repo",
				name: defaultLibName,
			},
		},
		{
			importpath: "example.com/repo/lib",
			want: label{
				repo: "com_example_repo",
				pkg:  "lib",
				name: defaultLibName,
			},
		},
		{
			importpath: "example.com/repo.git/lib",
			want: label{
				repo: "com_example_repo_git",
				pkg:  "lib",
				name: defaultLibName,
			},
		},
		{
			importpath: "example.com/lib",
			want: label{
				repo: "com_example",
				pkg:  "lib",
				name: defaultLibName,
			},
		},
	} {
		l, err := r.resolve(spec.importpath, "some/package")
		if err != nil {
			t.Errorf("r.resolve(%q) failed with %v; want success", spec.importpath, err)
			continue
		}
		if got, want := l, spec.want; !reflect.DeepEqual(got, want) {
			t.Errorf("r.resolve(%q) = %s; want %s", spec.importpath, got, want)
		}
	}
}

// stubRepoRootForImportPath is a stub implementation of vcs.RepoRootForImportPath
func stubRepoRootForImportPath(importpath string, verbose bool) (*vcs.RepoRoot, error) {
	if strings.HasPrefix(importpath, "example.com/repo.git") {
		return &vcs.RepoRoot{
			VCS:  vcs.ByCmd("git"),
			Repo: "https://example.com/repo.git",
			Root: "example.com/repo.git",
		}, nil
	}

	if strings.HasPrefix(importpath, "example.com/repo") {
		return &vcs.RepoRoot{
			VCS:  vcs.ByCmd("git"),
			Repo: "https://example.com/repo.git",
			Root: "example.com/repo",
		}, nil
	}

	return &vcs.RepoRoot{
		VCS:  vcs.ByCmd("git"),
		Repo: "https://example.com",
		Root: "example.com",
	}, nil
}
