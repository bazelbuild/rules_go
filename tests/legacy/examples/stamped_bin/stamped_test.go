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

package no_prefix_test

import (
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

const mainFiles = `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_test", "go_library")

go_library(
    name = "stamp",
    srcs = ["stamp.go"],
    importpath = "github.com/bazelbuild/rules_go/examples/stamped_bin/stamp",
    visibility = ["//visibility:public"],
    x_defs = {
        "XdefBuildTimestamp": "{BUILD_TIMESTAMP}",
    },
)

go_test(
    name = "stamp_with_x_defs",
    size = "small",
    srcs = ["stamped_bin_test.go"],
    x_defs = {
        "github.com/bazelbuild/rules_go/examples/stamped_bin/stamp.BUILD_TIMESTAMP": "{BUILD_TIMESTAMP}",
        "github.com/bazelbuild/rules_go/examples/stamped_bin/stamp.PassIfEmpty": "",
        "github.com/bazelbuild/rules_go/examples/stamped_bin/stamp.XdefInvalid": "{Undefined_Var}",  # undefined should leave the var alone
        "github.com/bazelbuild/rules_go/examples/stamped_bin/stamp.Multiple": "{BUILD_TIMESTAMP}{BUILD_TIMESTAMP}",
    },
    deps = [":stamp"],
)

-- stamp.go --
package stamp

var BUILD_TIMESTAMP = "fail"

// an xdef should set this to ""
var PassIfEmpty = "fail"

// an xdef should set this to nonempty
var XdefBuildTimestamp = ""

// an xdef with a missing key should leave this alone
var XdefInvalid = "pass"

// an xdef with multiple keys
var Multiple = "fail"

-- stamped_bin_test.go --
package stamped_bin_test

import (
	"testing"

	"github.com/bazelbuild/rules_go/examples/stamped_bin/stamp"
)

func TestStampedBin(t *testing.T) {
	// If we use an x_def when linking to override BUILD_TIMESTAMP but fail to
	// pass through the workspace status value, it'll be set to empty string -
	// overridden but still wrong. Check for that case too.
	if stamp.BUILD_TIMESTAMP == "fail" || stamp.BUILD_TIMESTAMP == "" {
		t.Errorf("Expected timestamp to have been modified, got %s.", stamp.BUILD_TIMESTAMP)
	}
	if stamp.XdefBuildTimestamp == "" {
		t.Errorf("Expected XdefBuildTimestamp to have been modified, got %s.", stamp.XdefBuildTimestamp)
	}
	if stamp.PassIfEmpty != "" {
		t.Errorf("Expected PassIfEmpty to have been set to '', got %s.", stamp.PassIfEmpty)
	}
	if stamp.XdefInvalid != "pass" {
		t.Errorf("Expected XdefInvalid to have been left alone, got %s.", stamp.XdefInvalid)
	}
	if stamp.Multiple != stamp.BUILD_TIMESTAMP + stamp.BUILD_TIMESTAMP {
		t.Errorf("Expected Multiple to have two BUILD_TIMESTAMP, got %s.", stamp.Multiple)
	}
}

`

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: mainFiles,
	})
}

func TestBuild(t *testing.T) {
	if err := bazel_testing.RunBazel("test", "--stamp", ":all"); err != nil {
		t.Fatal(err)
	}
}

func TestBuildWithoutStamp(t *testing.T) {
	if err := bazel_testing.RunBazel("test", "--nostamp", ":all"); err != nil {
		if eErr, ok := err.(*bazel_testing.StderrExitError); ok {
			if eErr.Err.ExitCode() == 3 { // 3 is TEST_FAILED bazel exit code
				return
			}
			t.Fatalf("expected tests to have failed (instead got exit code %d)", eErr.Err.ExitCode())
		}
		t.Fatal("expected bazel_testing.StderrExitError")
	}
	t.Fatal("expected error")
}
