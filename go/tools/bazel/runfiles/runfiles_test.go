// Copyright 2020, 2021, 2022 Google LLC
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

package runfiles_test

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel/runfiles"
)

func ExamplePath() {
	path, err := runfiles.Path("io_bazel_rules_go/go/tools/bazel/runfiles/test.txt")
	if err != nil {
		panic(err)
	}
	b, err := os.ReadFile(path)
	if err != nil {
		panic(err)
	}
	fmt.Println(string(b))
	// Output: hi!
}

func ExampleRunfiles() {
	r, err := runfiles.New()
	if err != nil {
		panic(err)
	}
	// The binary “testprog” is itself built with Bazel, and needs
	// runfiles.
	prog, err := r.Path("io_bazel_rules_go/go/tools/bazel/runfiles/testprog/testprog")
	if err != nil {
		panic(err)
	}
	if runtime.GOOS == "windows" {
		// TODO: fixme
		// panic: exec: "...testprog\\testprog": file does not exist [recovered]
		return
	}
	cmd := exec.Command(prog)
	// We add r.Env() after os.Environ() so that runfile environment
	// variables override anything set in the process environment.
	cmd.Env = append(os.Environ(), r.Env()...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		panic(err)
	}
	// Output: hi!
}

func TestPath_errors(t *testing.T) {
	r, err := runfiles.New()
	if err != nil {
		t.Fatal(err)
	}
	for _, s := range []string{"", "/..", "../", "a/../b", "a//b", "a/./b", `\a`} {
		t.Run(s, func(t *testing.T) {
			if got, err := r.Path(s); err == nil {
				t.Errorf("got %q, want error", got)
			}
		})
	}
}

func TestRunfiles_zero(t *testing.T) {
	var r runfiles.Runfiles
	if got, err := r.Path("a"); err == nil {
		t.Errorf("Path: got %q, want error", got)
	}
	if got := r.Env(); got != nil {
		t.Errorf("Env: got %v, want nil", got)
	}
}

func TestRunfiles_empty(t *testing.T) {
	dir := t.TempDir()
	manifest := filepath.Join(dir, "manifest")
	if err := os.WriteFile(manifest, []byte("__init__.py \n"), 0o600); err != nil {
		t.Fatal(err)
	}
	r, err := runfiles.New(runfiles.ManifestFile(manifest))
	if err != nil {
		t.Fatal(err)
	}
	_, got := r.Path("__init__.py")
	want := runfiles.ErrEmpty
	if !errors.Is(got, want) {
		t.Errorf("Path for empty file: got error %q, want something that wraps %q", got, want)
	}
}

func TestRunfiles_manifestWithDir(t *testing.T) {
	dir := t.TempDir()
	manifest := filepath.Join(dir, "manifest")
	if err := os.WriteFile(manifest, []byte(filepath.FromSlash("foo/dir")+" "+filepath.FromSlash("path/to/foo/dir\n")), 0o600); err != nil {
		t.Fatal(err)
	}
	r, err := runfiles.New(runfiles.ManifestFile(manifest))
	if err != nil {
		t.Fatal(err)
	}

	for rlocation, want := range map[string]string{
		filepath.FromSlash("foo/dir"):                    filepath.FromSlash("path/to/foo/dir"),
		filepath.FromSlash("foo/dir/file"):               filepath.FromSlash("path/to/foo/dir/file"),
		filepath.FromSlash("foo/dir/deeply/nested/file"): filepath.FromSlash("path/to/foo/dir/deeply/nested/file"),
	} {
		t.Run(rlocation, func(t *testing.T) {
			got, err := r.Path(rlocation)
			if err != nil {
				t.Fatalf("Path failed: got unexpected error %q", err)
			}
			if got != want {
				t.Errorf("Path failed: got %q, want %q", got, want)
			}
		})
	}
}
