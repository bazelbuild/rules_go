# Copyright 2014 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Public definitions for Go rules.

All public Go rules, providers, and other definitions are imported and
re-exported in this file. This allows the real location of definitions
to change for easier maintenance.

Definitions outside this file are private unless otherwise noted, and
may change without notice.
"""

load(
    "//extras:gomock.bzl",
    _gomock = "gomock",
)
load(
    "//go/private:context.bzl",
    _go_context = "go_context",
)
load(
    "//go/private:go_toolchain.bzl",
    _go_toolchain = "go_toolchain",
)
load(
    "//go/private:providers.bzl",
    _GoArchive = "GoArchive",
    _GoArchiveData = "GoArchiveData",
    _GoLibrary = "GoLibrary",
    _GoPath = "GoPath",
    _GoSDK = "GoSDK",
    _GoSource = "GoSource",
)
load(
    "//go/private/rules:cross.bzl",
    _go_cross_binary = "go_cross_binary",
)
load(
    "//go/private/rules:library.bzl",
    _go_tool_library = "go_tool_library",
)
load(
    "//go/private/rules:nogo.bzl",
    _nogo = "nogo_wrapper",
)
load(
    "//go/private/rules:sdk.bzl",
    _go_sdk = "go_sdk",
)
load(
    "//go/private/rules:source.bzl",
    _go_source = "go_source",
)
load(
    "//go/private/rules:wrappers.bzl",
    _go_binary_macro = "go_binary_macro",
    _go_library_macro = "go_library_macro",
    _go_test_macro = "go_test_macro",
)
load(
    "//go/private/tools:path.bzl",
    _go_path = "go_path",
)

_TOOLS_NOGO = [
    # keep sorted
    "appends",
    "asmdecl",
    "assign",
    "atomic",
    "atomicalign",
    "bools",
    "buildssa",
    "buildtag",
    # TODO(#2396): pass raw cgo sources to cgocall and re-enable.
    # "cgocall",
    "composite",
    "copylock",
    "ctrlflow",
    "deepequalerrors",
    "defers",
    "directive",
    "errorsas",
    # Noisy and not actionable in some cases.
    # "fieldalignment",
    "findcall",
    "framepointer",
    "httpmux",
    "httpresponse",
    "ifaceassert",
    "inspect",
    "loopclosure",
    "lostcancel",
    "nilfunc",
    "nilness",
    "pkgfact",
    "printf",
    "reflectvaluecompare",
    "shadow",
    "shift",
    "sigchanyzer",
    "slog",
    "sortslice",
    "stdmethods",
    "stringintconv",
    "structtag",
    "testinggoroutine",
    "tests",
    "timeformat",
    "unmarshal",
    "unreachable",
    "unsafeptr",
    "unusedresult",
    "unusedwrite",
    "usesgenerics",
]

# TOOLS_NOGO is a list of all analysis passes in
# golang.org/x/tools/go/analysis/passes.
# This is not backward compatible, so use caution when depending on this --
# new analyses may discover issues in existing builds.
TOOLS_NOGO = [str(Label("@org_golang_x_tools//go/analysis/passes/{}".format(p))) for p in _TOOLS_NOGO]

# Current version or next version to be tagged. Gazelle and other tools may
# check this to determine compatibility.
RULES_GO_VERSION = "0.46.0"

go_context = _go_context
gomock = _gomock
go_sdk = _go_sdk
go_tool_library = _go_tool_library
go_toolchain = _go_toolchain
nogo = _nogo

# See go/providers.rst#GoLibrary for full documentation.
GoLibrary = _GoLibrary

# See go/providers.rst#GoSource for full documentation.
GoSource = _GoSource

# See go/providers.rst#GoPath for full documentation.
GoPath = _GoPath

# See go/providers.rst#GoArchive for full documentation.
GoArchive = _GoArchive

# See go/providers.rst#GoArchiveData for full documentation.
GoArchiveData = _GoArchiveData

# See go/providers.rst#GoSDK for full documentation.
GoSDK = _GoSDK

# See docs/go/core/rules.md#go_library for full documentation.
go_library = _go_library_macro

# See docs/go/core/rules.md#go_binary for full documentation.
go_binary = _go_binary_macro

# See docs/go/core/rules.md#go_test for full documentation.
go_test = _go_test_macro

# See docs/go/core/rules.md#go_test for full documentation.
go_source = _go_source

# See docs/go/core/rules.md#go_path for full documentation.
go_path = _go_path

# See docs/go/core/rules.md#go_cross_binary for full documentation.
go_cross_binary = _go_cross_binary

def go_vet_test(*_args, **_kwargs):
    fail("The go_vet_test rule has been removed. Please migrate to nogo instead, which supports vet tests.")

def go_rule(**_kwargs):
    fail("The go_rule function has been removed. Use rule directly instead. See https://github.com/bazelbuild/rules_go/blob/master/go/toolchains.rst#writing-new-go-rules")

def go_rules_dependencies():
    _moved("go_rules_dependencies")

def go_register_toolchains(**_kwargs):
    _moved("go_register_toolchains")

def go_download_sdk(**_kwargs):
    _moved("go_download_sdk")

def go_host_sdk(**_kwargs):
    _moved("go_host_sdk")

def go_local_sdk(**_kwargs):
    _moved("go_local_sdk")

def go_wrap_sdk(**_kwargs):
    _moved("go_wrap_sdK")

def _moved(name):
    fail(name + " has moved. Please load from " +
         " @io_bazel_rules_go//go:deps.bzl instead of def.bzl.")
