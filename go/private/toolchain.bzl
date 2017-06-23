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

GO_SELECT_TOOLCHAIN_BUILD_FILE = """
exports_files(["BUILD.bazel"])

alias(
    name = "go_toolchain",
    actual = "{toolchain}",
    visibility = ["//visibility:public"],
)

alias(
    name = "bootstrap_toolchain",
    actual = "{bootstrap}",
    visibility = ["//visibility:public"],
)
"""

def _go_sdk_repository_impl(ctx):
  ctx.download_and_extract(
      url = ctx.attr.url,
      stripPrefix = ctx.attr.strip_prefix,
      sha256 = ctx.attr.sha256)
  goroot = ctx.path(".")
  ctx.template("BUILD.bazel", 
    Label("@io_bazel_rules_go//go/private:BUILD.sdk.bazel"),
    substitutions = {"{goroot}": str(goroot)}, 
    executable = False,
  )

go_sdk_repository = repository_rule(
    implementation = _go_sdk_repository_impl, 
    attrs = {
        "url" : attr.string(),
        "strip_prefix" : attr.string(),
        "sha256" : attr.string(),
    },
)

def _go_repository_select_impl(ctx):
  host = ""
  if ctx.os.name == 'linux':
    host = 'linux-x86_64'
  elif ctx.os.name == 'mac os x':
    host = 'osx-x86_64'
  else:
    fail("Unsupported operating system: " + ctx.os.name)
  toolchain = ctx.os.environ.get("GO_TOOLCHAIN")
  if not toolchain:
    toolchain = "@io_bazel_rules_go//go/toolchain:go"+ctx.attr.go_version+"-"+host
  bootstrap = toolchain.split("-cross-")[0] + "-bootstrap"

  ctx.file("BUILD.bazel", GO_SELECT_TOOLCHAIN_BUILD_FILE.format(
      toolchain = toolchain,
      bootstrap = bootstrap,
  ))

go_repository_select = repository_rule(
    implementation = _go_repository_select_impl,
    environ = ["GO_TOOLCHAIN"],
    attrs = {
        "go_version" : attr.string(default = "1.8.3"),
    })
