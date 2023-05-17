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

package nolint_test

import (
	"bytes"
	"io/ioutil"
	"strings"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_library", "go_tool_library", "nogo")

nogo(
    name = "nogo",
    vet = True,
    visibility = ["//visibility:public"],
)

go_library(
    name = "has_errors",
    srcs = ["has_errors.go"],
    importpath = "haserrors",
)

-- has_errors.go --
package haserrors

//nolint:buildtag
// +build build_tags_error

import (
	"fmt"
	"sync/atomic"
)

func F() {}

func Foo() bool {
	x := uint64(1)
	_ = atomic.AddUint64(&x, 1)
	if F == nil { //nolint:all
		return false
	}
	fmt.Printf("%b", "hi", true || true) //nolint:printf,bools
	return true || true //nolint
}

func InlineComment() {
	s := "hello" // nolint
	fmt.Printf("%d", s)
}

func LinterMatch() bool {
	return true || true //nolint:printf
}
`,
	})
}

func Test(t *testing.T) {
	customRegister := `go_register_toolchains(nogo = "@//:nogo")`
	if err := replaceInFile("WORKSPACE", "go_register_toolchains()", customRegister); err != nil {
		t.Fatal(err)
	}

	cmd := bazel_testing.BazelCmd("build", "//:has_errors")
	stderr := &bytes.Buffer{}
	cmd.Stderr = stderr
	if err := cmd.Run(); err == nil {
		t.Fatal("unexpected success")
	}

	expected := []string{
		"has_errors.go:25:2: fmt.Printf format %d has arg s of wrong type string (printf)",
		"has_errors.go:29:9: redundant or: true || true (bools)",
	}

	output := stderr.String()
	for _, ex := range expected {
		if !strings.Contains(output, ex) {
			t.Errorf("output did not match expected: %s", ex)
		}
	}
}

func replaceInFile(path, old, new string) error {
	data, err := ioutil.ReadFile(path)
	if err != nil {
		return err
	}
	data = bytes.ReplaceAll(data, []byte(old), []byte(new))
	return ioutil.WriteFile(path, data, 0666)
}
