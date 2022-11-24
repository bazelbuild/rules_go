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
	"encoding/json"
	"fmt"
	"strings"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")
load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@rules_proto//proto:defs.bzl", "proto_library")

go_binary(
    name = "main",
    srcs = [
        "main.go",
        ":gen_go",
    ],
    data = [":helper"],
    embedsrcs = [":helper"],
    cdeps = [":helper"],
    cgo = True,
    linkmode = "c-archive",
    gotags = ["foo"],
    deps = [":lib"],
)

go_library(
    name = "lib",
    srcs = [
        "lib.go",
        ":gen_indirect_go",
    ],
    importpath = "example.com/lib",
    data = [":indirect_helper"],
    embedsrcs = [":indirect_helper"],
    cdeps = [":indirect_helper"],
    cgo = True,
)

go_test(
    name = "main_test",
    srcs = [
        "main.go",
        ":gen_go",
    ],
    data = [":helper"],
    embedsrcs = [":helper"],
    cdeps = [":helper"],
    cgo = True,
    linkmode = "c-archive",
    gotags = ["foo"],
)

cc_library(
    name = "helper",
)

cc_library(
    name = "indirect_helper",
)

genrule(
    name = "gen_go",
    outs = ["gen.go"],
    exec_tools = [":helper"],
    cmd = "# Not needed for bazel cquery",
)

genrule(
    name = "gen_indirect_go",
    outs = ["gen_indirect.go"],
    exec_tools = [":indirect_helper"],
    cmd = "# Not needed for bazel cquery",
)

proto_library(
    name = "foo_proto",
    srcs = ["foo.proto"],
)

go_proto_library(
    name = "foo_go_proto",
    importpath = "github.com/bazelbuild/rules_go/tests/core/transition/foo",
    proto = ":foo_proto",
)
-- main.go --
package main

func main() {}
-- lib.go --
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

func TestGoBinaryNonGoAttrsAreReset(t *testing.T) {
	assertDependsCleanlyOnWithFlags(
		t,
		"//:main",
		"//:helper")
}

func TestGoLibraryNonGoAttrsAreReset(t *testing.T) {
	assertDependsCleanlyOnWithFlags(
		t,
		"//:main",
		"//:indirect_helper")
}

func TestGoTestNonGoAttrsAreReset(t *testing.T) {
	assertDependsCleanlyOnWithFlags(
		t,
		"//:main_test",
		"//:helper")
}

func TestGoProtoLibraryToolAttrsAreReset(t *testing.T) {
	assertDependsCleanlyOnWithFlags(
		t,
		"//:foo_go_proto",
		"@com_google_protobuf//:protoc",
		"--@io_bazel_rules_go//go/config:static",
		"--@io_bazel_rules_go//go/config:msan",
		"--@io_bazel_rules_go//go/config:race",
		"--@io_bazel_rules_go//go/config:debug",
		"--@io_bazel_rules_go//go/config:linkmode=c-archive",
		"--@io_bazel_rules_go//go/config:tags=fake_tag",
	)
	assertDependsCleanlyOnWithFlags(
		t,
		"//:foo_go_proto",
		"@com_google_protobuf//:protoc",
		"--@io_bazel_rules_go//go/config:pure",
	)
}

func assertDependsCleanlyOnWithFlags(t *testing.T, targetA, targetB string, flags ...string) {
	query := fmt.Sprintf("deps(%s) intersect %s", targetA, targetB)
	out, err := bazel_testing.BazelOutput(append(
		[]string{
			"cquery",
			"--transitions=full",
			"--output=jsonproto",
			query,
		},
		flags...,
	)...,
	)
	if err != nil {
		t.Fatalf("bazel cquery '%s': %v", query, err)
	}
	cqueryOut := bytes.TrimSpace(out)
	configHashes := extractConfigHashes(t, cqueryOut)
	if len(configHashes) != 1 {
		differingGoOptions := getGoOptions(t, configHashes...)
		if len(differingGoOptions) != 0 {
			t.Fatalf(
				"%s depends on %s in multiple configs with these differences in rules_go options: %s",
				targetA,
				targetB,
				strings.Join(differingGoOptions, "\n"),
			)
		}
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

func extractConfigHashes(t *testing.T, rawJsonOut []byte) []string {
	var jsonOut bazelCqueryOutput
	err := json.Unmarshal(rawJsonOut, &jsonOut)
	if err != nil {
		t.Fatalf("Failed to decode bazel config JSON output %v: %q", err, string(rawJsonOut))
	}
	var hashes []string
	for _, result := range jsonOut.Results {
		hashes = append(hashes, result.Configuration.Checksum)
	}
	return hashes
}

func getGoOptions(t *testing.T, hashes ...string) []string {
	out, err := bazel_testing.BazelOutput(append([]string{"config", "--output=json"}, hashes...)...)
	if err != nil {
		t.Fatalf("bazel config %s: %v", strings.Join(hashes, " "), err)
	}
	rawJsonOut := bytes.TrimSpace(out)
	var jsonOut bazelConfigOutput
	err = json.Unmarshal(rawJsonOut, &jsonOut)
	if err != nil {
		t.Fatalf("Failed to decode bazel config JSON output %v: %q", err, string(rawJsonOut))
	}
	var differingGoOptions []string
	for _, fragment := range jsonOut.Fragments {
		if fragment.Name != starlarkOptionsFragment {
			continue
		}
		for key, value := range fragment.Options {
			if strings.HasPrefix(key, "@io_bazel_rules_go//") {
				differingGoOptions = append(differingGoOptions, fmt.Sprintf("%s=%s", key, value))
			}
		}
	}
	return differingGoOptions
}

const starlarkOptionsFragment = "user-defined"

type bazelConfigOutput struct {
	Fragments []struct {
		Name    string            `json:"name"`
		Options map[string]string `json:"options"`
	} `json:"fragmentOptions"`
}

type bazelCqueryOutput struct {
	Results []struct {
		Configuration struct {
			Checksum string `json:"checksum"`
		} `json:"configuration"`
	} `json:"results"`
}
