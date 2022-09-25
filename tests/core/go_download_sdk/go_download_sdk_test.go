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
		desc, rule       string
		optToWantVersion map[string]string
	}{
		{
			desc: "version",
			rule: `
load("@io_bazel_rules_go//go:deps.bzl", "go_download_sdk")

go_download_sdk(
    name = "go_sdk",
    version = "1.16",
)

`,
			optToWantVersion: map[string]string{"": "go1.16"},
		}, {
			desc: "custom_archives",
			rule: `
load("@io_bazel_rules_go//go:deps.bzl", "go_download_sdk")

go_download_sdk(
    name = "go_sdk",
    sdks = {
        "darwin_amd64": ("go1.16.darwin-amd64.tar.gz", "6000a9522975d116bf76044967d7e69e04e982e9625330d9a539a8b45395f9a8"),
        "darwin_arm64": ("go1.16.darwin-arm64.tar.gz", "4dac57c00168d30bbd02d95131d5de9ca88e04f2c5a29a404576f30ae9b54810"),
        "linux_amd64": ("go1.16.linux-amd64.tar.gz", "013a489ebb3e24ef3d915abe5b94c3286c070dfe0818d5bca8108f1d6e8440d2"),
        "windows_amd64": ("go1.16.windows-amd64.zip", "5cc88fa506b3d5c453c54c3ea218fc8dd05d7362ae1de15bb67986b72089ce93"),
    },
)
`,
			optToWantVersion: map[string]string{"": "go1.16"},
		},
		{
			desc: "multiple_sdks",
			rule: `
load("@io_bazel_rules_go//go:deps.bzl", "go_download_sdk", "go_host_sdk")

go_download_sdk(
    name = "go_sdk",
    version = "1.16",
)
go_download_sdk(
    name = "go_sdk_1_17",
    version = "1.17",
)
go_download_sdk(
    name = "go_sdk_1_17_1",
    version = "1.17.1",
)
`,
			optToWantVersion: map[string]string{
				"": "go1.16",
				"--@io_bazel_rules_go//go/toolchain:sdk_version=remote": "go1.16",
				"--@io_bazel_rules_go//go/toolchain:sdk_version=1":      "go1.16",
				"--@io_bazel_rules_go//go/toolchain:sdk_version=1.17":   "go1.17",
				"--@io_bazel_rules_go//go/toolchain:sdk_version=1.17.0": "go1.17",
				"--@io_bazel_rules_go//go/toolchain:sdk_version=1.17.1": "go1.17.1",
			},
		},
	} {
		t.Run(test.desc, func(t *testing.T) {
			origWorkspaceData, err := ioutil.ReadFile("WORKSPACE")
			if err != nil {
				t.Fatal(err)
			}

			i := bytes.Index(origWorkspaceData, []byte("go_rules_dependencies()"))
			if i < 0 {
				t.Fatal("could not find call to go_rules_dependencies()")
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

			for opt, wantVersion := range test.optToWantVersion {
				t.Run(wantVersion, func(t *testing.T) {
					args := []string{
						"test",
						"//:version_test",
						"--test_arg=-version=" + wantVersion,
					}
					if opt != "" {
						args = append(args, opt)
					}
					if err := bazel_testing.RunBazel(args...); err != nil {
						t.Fatal(err)
					}
				})
			}
		})
	}
}
