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

def executable_extension(ctx):
  extension = ""
  if ctx.os.name.startswith('windows'):
    extension = ".exe"
  return extension

def _go_host_sdk_impl(ctx):
  path = _detect_host_sdk(ctx)
  _local_sdk(ctx, path)
  _sdk_build_file(ctx, path)

go_host_sdk = repository_rule(_go_host_sdk_impl, environ = ["GOROOT"])
"""go_host_sdk is a specialization of go_sdk just to add the GOROOT dependancy"""

def _go_sdk_impl(ctx):
  urls = ctx.attr.urls
  if ctx.attr.url:
    print("DEPRECATED: use urls instead of url on go_sdk, {}".format(ctx.attr.url))
    urls = [ctx.attr.url] + urls
  if urls:
    if ctx.attr.path:
      fail("url and path cannot both be set on go_sdk, got {} and {}".format(urls, ctx.attr.path))
    _sdk_build_file(ctx, str(ctx.path(".")))
    _remote_sdk(ctx, urls, ctx.attr.strip_prefix, ctx.attr.sha256)
  elif ctx.attr.path:
    _sdk_build_file(ctx, ctx.attr.path)
    _local_sdk(ctx, ctx.attr.path)
  else:
    path = _detect_host_sdk(ctx)
    _sdk_build_file(ctx, path)
    _local_sdk(ctx, path)

  if "TMP" in ctx.os.environ:
    tmp = ctx.os.environ["TMP"]
    ctx.symlink(tmp, "tmp")
  else:
    ctx.file("tmp/ignore", content="") # make a file to force the directory to exist
    tmp = str(ctx.path("tmp").realpath)

  # Build the standard library for valid cross compile platforms
  #TODO: fix standard library cross compilation
  if ctx.name.endswith("linux_amd64") and ctx.os.name == "linux":
    _cross_compile_stdlib(ctx, "windows", "amd64", tmp)
  if ctx.name.endswith("darwin_amd64") and ctx.os.name == "mac os x":
    _cross_compile_stdlib(ctx, "linux", "amd64", tmp)

go_sdk = repository_rule(
    implementation = _go_sdk_impl,
    attrs = {
        "path": attr.string(),
        "url": attr.string(),
        "urls": attr.string_list(),
        "strip_prefix": attr.string(default="go"),
        "sha256": attr.string(),
    },
)
"""See /go/toolchains.rst#go-sdk for full documentation."""

def _remote_sdk(ctx, urls, strip_prefix, sha256):
  ctx.download_and_extract(
      url = urls,
      stripPrefix = strip_prefix,
      sha256 = sha256,
  )

def _local_sdk(ctx, path):
  for entry in ["src", "pkg", "bin"]:
    ctx.symlink(path+"/"+entry, entry)

def _sdk_build_file(ctx, goroot):
  ctx.template("BUILD.bazel",
      Label("@io_bazel_rules_go//go/private:BUILD.sdk.bazel"),
      substitutions = {"{goroot}": goroot, "{extension}": executable_extension(ctx)},
      executable = False,
  )

def _cross_compile_stdlib(ctx, goos, goarch, tmp):
  env = {
      "CGO_ENABLED": "0",
      "GOROOT": str(ctx.path(".")),
      "GOOS": goos,
      "GOARCH": goarch,
      "TMP": tmp,
  }
  res = ctx.execute(
      ["bin/go"+executable_extension(ctx), "install", "-v", "std"],
      environment = env,
  )
  if res.return_code:
    print("failed: ", res.stderr)
    fail("go standard library cross compile %s to %s-%s failed" % (ctx.name, goos, goarch))
  res = ctx.execute(
      ["bin/go"+executable_extension(ctx), "install", "-v", "runtime/cgo"],
      environment = env,
  )
  if res.return_code:
    print("failed: ", res.stderr)
    fail("go runtime cgo cross compile %s to %s-%s failed" % (ctx.name, goos, goarch))

def _detect_host_sdk(ctx):
  root = "@invalid@"
  if "GOROOT" in ctx.os.environ:
    return ctx.os.environ["GOROOT"]
  res = ctx.execute(["go"+executable_extension(ctx), "env", "GOROOT"])
  if res.return_code:
    fail("Could not detect host go version")
  root = res.stdout.strip()
  if not root:
    fail("host go version failed to report it's GOROOT")
  return root

