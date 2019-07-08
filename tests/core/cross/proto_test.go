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
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

git_repository(
    name = "com_google_protobuf",
    commit = "09745575a923640154bcf307fba8aedff47f240a",
    remote = "https://github.com/protocolbuffers/protobuf",
    shallow_since = "1558721209 -0700",
)

load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")

protobuf_deps()
`,
	Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//proto:def.bzl", "go_proto_library")

proto_library(
    name = "cross_proto",
    srcs = ["cross.proto"],
)

go_proto_library(
    name = "cross_go_proto",
    importpath = "github.com/bazelbuild/rules_go/tests/core/cross",
    protos = [":cross_proto"],
)

-- cross.proto --
syntax = "proto3";

package cross;

option go_package = "github.com/bazelbuild/rules_go/tests/core/cross";

message Foo {
  int64 x = 1;
}
`,
}

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, testArgs)
}

func TestProto(t *testing.T) {
	args := []string{
		"build",
		"--platforms=@io_bazel_rules_go//go/toolchain:ios_amd64",
		":cross_go_proto",
	}
	if err := bazel_testing.RunBazel(args...); err != nil {
		t.Fatal(err)
	}
}
