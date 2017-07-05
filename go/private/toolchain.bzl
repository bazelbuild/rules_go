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
  # Build the standard library for valid cross compile platforms
  if ctx.name.endswith("linux_amd64"):
    _cross_compile_stdlib(ctx, "windows", "amd64")
  if ctx.name.endswith("darwin_amd64"):
    _cross_compile_stdlib(ctx, "linux", "amd64")

def _cross_compile_stdlib(ctx, goos, goarch):
  env = {
      "CGO_ENABLED": "0",
      "GOROOT": str(ctx.path(".")),
      "GOOS": goos,
      "GOARCH": goarch,
  }
  res = ctx.execute(
      ["bin/go", "install", "-v", "std"], 
      environment = env,
  )
  if res.return_code:
    print("failed: ", res.stderr)
    fail("go standard library cross compile %s to %s-%s failed" % (ctx.name, goos, goarch))
  res = ctx.execute(
      ["bin/go", "install", "-v", "runtime/cgo"], 
      environment = env,
  )
  if res.return_code:
    print("failed: ", res.stderr)
    fail("go runtime cgo cross compile %s to %s-%s failed" % (ctx.name, goos, goarch))

go_sdk_repository = repository_rule(
    implementation = _go_sdk_repository_impl, 
    attrs = {
        "url" : attr.string(),
        "strip_prefix" : attr.string(),
        "sha256" : attr.string(),
    },
)
