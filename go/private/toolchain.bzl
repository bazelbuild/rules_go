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

def _go_host_sdk_impl(ctx):
  path = _detect_host_sdk(ctx)
  _local_sdk(ctx, path)
  _sdk_build_file(ctx, path)

go_host_sdk = repository_rule(_go_host_sdk_impl, environ = ["GOROOT"])
"""go_host_sdk is a specialization of go_sdk just to add the GOROOT dependancy"""

def _go_sdk_impl(ctx):
  if ctx.attr.url:
    if ctx.attr.path:
      fail("url and path cannot both be set on go_sdk, got {} and {}".format(ctx.attr.url, ctx.attr.path))
    _remote_sdk(ctx, ctx.attr.url, ctx.attr.strip_prefix, ctx.attr.sha256)
    _sdk_build_file(ctx, str(ctx.path(".")))
  elif ctx.attr.path:
    _local_sdk(ctx, ctx.attr.path)
    _sdk_build_file(ctx, ctx.attr.path)
  else:
    path = _detect_host_sdk(ctx)
    _local_sdk(ctx, path)
    _sdk_build_file(ctx, path)
    
  # Build the standard library for valid cross compile platforms
  #TODO: fix standard library cross compilation
  if ctx.name.endswith("linux_amd64") and ctx.os.name == "linux":
    _cross_compile_stdlib(ctx, "windows", "amd64")
  if ctx.name.endswith("darwin_amd64") and ctx.os.name == "mac os x":
    _cross_compile_stdlib(ctx, "linux", "amd64")

go_sdk = repository_rule(
    implementation = _go_sdk_impl, 
    attrs = {
        "path": attr.string(),
        "url": attr.string(),
        "strip_prefix": attr.string(default="go"),
        "sha256": attr.string(),
    },
)
"""
    go_sdk is a rule for adding a new go SDK to the available set.
    This does not make the sdk available for use directly, it needs to be exposed through a toolchain.
    If you do not specify url or path, then it will attempt to detect the installed version of go.
"""

def _remote_sdk(ctx, url, strip_prefix, sha256):
  ctx.download_and_extract(
      url = ctx.attr.url,
      stripPrefix = ctx.attr.strip_prefix,
      sha256 = ctx.attr.sha256,
  )

def _local_sdk(ctx, path):
  for entry in ["src", "pkg", "bin"]:
    ctx.symlink(path+"/"+entry, entry)

def _sdk_build_file(ctx, goroot):
  ctx.template("BUILD.bazel", 
      Label("@io_bazel_rules_go//go/private:BUILD.sdk.bazel"),
      substitutions = {"{goroot}": goroot},
      executable = False,
  )

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

def _detect_host_sdk(ctx):
  root = "@invalid@"
  if "GOROOT" in ctx.os.environ:
    return ctx.os.environ["GOROOT"]
  res = ctx.execute(["go", "env", "GOROOT"])
  if res.return_code:
    fail("Could not detect host go version")
  root = res.stdout.strip()
  if not root:
    fail("host go version failed to report it's GOROOT")
  return root

