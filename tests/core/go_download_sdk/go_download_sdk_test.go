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

package go_download_sdk_test

import (
	"bytes"
	"io/ioutil"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_test")

go_test(
    name = "version_test",
    srcs = ["version_test.go"],
)

-- version_test.go --
package version_test

import (
	"flag"
	"runtime"
	"testing"
)

var want = flag.String("version", "", "")

func Test(t *testing.T) {
	if v := runtime.Version(); v != *want {
		t.Errorf("got version %q; want %q", v, *want)
	}
}
`,
	})
}

func Test(t *testing.T) {
	for _, test := range []struct {
		desc, rule, wantVersion string
	}{
		{
			desc: "version",
			rule: `
load("@io_bazel_rules_go//go:deps.bzl", "go_download_sdk")

go_download_sdk(
    name = "go_sdk",
    version = "1.13",
)

`,
			wantVersion: "go1.13",
		}, {
			desc: "custom_archives",
			rule: `
load("@io_bazel_rules_go//go:deps.bzl", "go_download_sdk")

go_download_sdk(
    name = "go_sdk",
    sdks = {
        "darwin_amd64": ("go1.13.darwin-amd64.tar.gz", "234ebbba1fbed8474340f79059cfb3af2a0f8b531c4ff0785346e0710e4003dd"),
        "linux_amd64": ("go1.13.linux-amd64.tar.gz", "68a2297eb099d1a76097905a2ce334e3155004ec08cdea85f24527be3c48e856"),
        "windows_amd64": ("go1.13.windows-amd64.zip", "7d162b83157d3171961f8e05a55b7da8476244df3fac28a5da1c9e215acfea89"),
    },
)
`,
			wantVersion: "go1.13",
		},
	} {
		t.Run(test.desc, func(t *testing.T) {
			origWorkspaceData, err := ioutil.ReadFile("WORKSPACE")
			if err != nil {
				t.Fatal(err)
			}

			i := bytes.Index(origWorkspaceData, []byte("go_rules_dependencies()"))
			if i < 0 {
				t.Fatalf("%s: could not find call to go_rules_dependencies()")
			}

			buf := &bytes.Buffer{}
			buf.Write(origWorkspaceData[:i])
			buf.WriteString(test.rule)
			buf.WriteString(`
go_rules_dependencies()

go_register_toolchains()
`)
			if err := ioutil.WriteFile("WORKSPACE", buf.Bytes(), 0666); err != nil {
				t.Fatal(err)
			}
			defer func() {
				if err := ioutil.WriteFile("WORKSPACE", origWorkspaceData, 0666); err != nil {
					t.Errorf("error restoring WORKSPACE: %v", err)
				}
			}()

			if err := bazel_testing.RunBazel("test", "//:version_test", "--test_arg=-version="+test.wantVersion); err != nil {
				t.Fatal(err)
			}
		})
	}
}
