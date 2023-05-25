// Copyright 2021 The Bazel Authors. All rights reserved.
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

package no_srcs

import (
	"bytes"
	"os"
	"strings"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_library")

[
    go_library(
        name = "lib_" + str(i),
        srcs = [],
        importpath = "example.com/some/path",
    )
    for i in range(1000)
]
`,
	})
}

func Test(t *testing.T) {
	commonArgs := []string{
		"--spawn_strategy=local",
		"--compilation_mode=dbg",
	}

	if err := bazel_testing.RunBazel(append([]string{"build", "//..."}, commonArgs...)...); err != nil {
		t.Fatal(err)
	}

	out, err := bazel_testing.BazelOutput(append([]string{"cquery", "--output=files", "//..."}, commonArgs...)...)
	if err != nil {
		t.Fatal(err)
	}
	archives := strings.Split(strings.TrimSpace(string(out)), "\n")

	if len(archives) != 1000 {
		t.Fatalf("expected 1000 archives, got %d", len(archives))
	}

	referenceContent, err := os.ReadFile(archives[0])
	if err != nil {
		t.Fatal(err)
	}

	for _, archive := range archives {
		content, err := os.ReadFile(archive)
		if err != nil {
			t.Fatal(err)
		}
		if !bytes.Equal(content, referenceContent) {
			t.Fatalf("expected all archives to be identical, got:\n\n%s\n\n%s\n", string(content), string(referenceContent))
		}
	}
}
