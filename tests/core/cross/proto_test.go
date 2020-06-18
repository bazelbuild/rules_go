// Copyright 2019 The Bazel Authors. All rights reserved.
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

package proto_test

import (
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

var testArgs = bazel_testing.Args{
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
	Main: `
-- BUILD.bazel --
load("@rules_proto//proto:defs.bzl", "proto_library")
load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")
load("@io_bazel_rules_go//go:def.bzl", "go_binary")

proto_library(
    name = "cross_proto",
    srcs = ["cross.proto"],
)

go_proto_library(
    name = "cross_go_proto",
    importpath = "github.com/bazelbuild/rules_go/tests/core/cross",
    protos = [":cross_proto"],
)

go_binary(
    name = "use_bin",
    srcs = ["use.go"],
    deps = [":cross_go_proto"],
    goos = "linux",
    goarch = "386",
)

go_binary(
    name = "use_shared",
    srcs = ["use.go"],
    deps = [":cross_go_proto"],
    linkmode = "c-shared",
)

-- cross.proto --
syntax = "proto3";

package cross;

option go_package = "github.com/bazelbuild/rules_go/tests/core/cross";

message Foo {
  int64 x = 1;
}

-- use.go --
package main

import _ "github.com/bazelbuild/rules_go/tests/core/cross"

func main() {}
`,
}

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, testArgs)
}

func TestCmdLine(t *testing.T) {
	args := []string{
		"build",
		"--platforms=@io_bazel_rules_go//go/toolchain:linux_386",
		":cross_go_proto",
	}
	if err := bazel_testing.RunBazel(args...); err != nil {
		t.Fatal(err)
	}
}

func TestTargets(t *testing.T) {
	for _, target := range []string{"//:use_bin", "//:use_shared"} {
		if err := bazel_testing.RunBazel("build", target); err != nil {
			t.Errorf("building target %s: %v", target, err)
		}
	}
}
