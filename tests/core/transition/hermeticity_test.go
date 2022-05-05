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

package hermeticity_test

import (
	"bytes"
	"fmt"
	"strings"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@rules_proto//proto:defs.bzl", "proto_library")

proto_library(
    name = "foo_proto",
    srcs = ["foo.proto"],
)

go_proto_library(
    name = "foo_go_proto",
    importpath = "github.com/bazelbuild/rules_go/tests/core/transition/foo",
    proto = ":foo_proto",
)
-- foo.proto --
syntax = "proto3";

package tests.core.transition.foo;
option go_package = "github.com/bazelbuild/rules_go/tests/core/transition/foo";

message Foo {
  int64 value = 1;
}
`,
		WorkspaceSuffix: `
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "com_google_protobuf",
    sha256 = "a79d19dcdf9139fa4b81206e318e33d245c4c9da1ffed21c87288ed4380426f9",
    strip_prefix = "protobuf-3.11.4",
    # latest, as of 2020-02-21
    urls = [
        "https://mirror.bazel.build/github.com/protocolbuffers/protobuf/archive/v3.11.4.tar.gz",
        "https://github.com/protocolbuffers/protobuf/archive/v3.11.4.tar.gz",
    ],
)

load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")

protobuf_deps()

http_archive(
    name = "rules_proto",
    sha256 = "4d421d51f9ecfe9bf96ab23b55c6f2b809cbaf0eea24952683e397decfbd0dd0",
    strip_prefix = "rules_proto-f6b8d89b90a7956f6782a4a3609b2f0eee3ce965",
    # master, as of 2020-01-06
    urls = [
        "https://mirror.bazel.build/github.com/bazelbuild/rules_proto/archive/f6b8d89b90a7956f6782a4a3609b2f0eee3ce965.tar.gz",
        "https://github.com/bazelbuild/rules_proto/archive/f6b8d89b90a7956f6782a4a3609b2f0eee3ce965.tar.gz",
    ],
)
`,
	})
}

func TestGoProtoLibraryToolAttrsAreReset(t *testing.T) {
	assertDependsCleanlyOn(t, "//:foo_go_proto", "@com_google_protobuf//:protoc")
}

func assertDependsCleanlyOn(t *testing.T, targetA, targetB string) {
	assertDependsCleanlyOnWithFlags(
		t,
		targetA,
		targetB,
		"--@io_bazel_rules_go//go/config:static",
		"--@io_bazel_rules_go//go/config:msan",
		"--@io_bazel_rules_go//go/config:race",
		"--@io_bazel_rules_go//go/config:debug",
		"--@io_bazel_rules_go//go/config:linkmode=c-archive",
		"--@io_bazel_rules_go//go/config:tags=fake_tag",
	)
	assertDependsCleanlyOnWithFlags(
		t,
		targetA,
		targetB,
		"--@io_bazel_rules_go//go/config:pure",
	)
}

func assertDependsCleanlyOnWithFlags(t *testing.T, targetA, targetB string, flags ...string) {
	query := fmt.Sprintf("deps(%s) intersect %s", targetA, targetB)
	out, err := bazel_testing.BazelOutput(append(
		[]string{
			"cquery",
			"--transitions=full",
			query,
		},
		flags...,
	)...,
	)
	if err != nil {
		t.Fatalf("bazel cquery '%s': %v", query, err)
	}
	cqueryOut := string(bytes.TrimSpace(out))
	configHashes := extractConfigHashes(t, cqueryOut)
	if len(configHashes) != 1 {
		t.Fatalf(
			"%s depends on %s in multiple configs with these differences in rules_go options: %s",
			targetA,
			targetB,
			strings.Join(getGoOptions(t, configHashes...), "\n"),
		)
	}
	goOptions := getGoOptions(t, configHashes[0])
	if len(goOptions) != 0 {
		t.Fatalf(
			"%s depends on %s in a config with rules_go options: %s",
			targetA,
			targetB,
			strings.Join(goOptions, "\n"),
		)
	}
}

func extractConfigHashes(t *testing.T, cqueryOut string) []string {
	lines := strings.Split(cqueryOut, "\n")
	var hashes []string
	for _, line := range lines {
		openingParens := strings.Index(line, "(")
		closingParens := strings.Index(line, ")")
		if openingParens == -1 || closingParens <= openingParens {
			t.Fatalf("failed to find config hash in cquery out line: %s", line)
		}
		hashes = append(hashes, line[openingParens+1:closingParens])
	}
	return hashes
}

func getGoOptions(t *testing.T, hashes ...string) []string {
	out, err := bazel_testing.BazelOutput(append([]string{"config"}, hashes...)...)
	if err != nil {
		t.Fatalf("bazel config %s: %v", strings.Join(hashes, " "), err)
	}
	lines := strings.Split(string(bytes.TrimSpace(out)), "\n")
	differingGoOptions := make([]string, 0)
	for _, line := range lines {
		// Lines with configuration options are indented
		if !strings.HasPrefix(line, "  ") {
			continue
		}
		optionAndValue := strings.TrimLeft(line, " ")
		if strings.HasPrefix(optionAndValue, "@io_bazel_rules_go//") {
			differingGoOptions = append(differingGoOptions, optionAndValue)
		}
	}
	return differingGoOptions
}
