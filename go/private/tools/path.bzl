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

load("@io_bazel_rules_go//go/private:providers.bzl", "GoLibrary", "GoPath")

def _go_path_impl(ctx):
  print("""
EXPERIMENTAL: the go_path rule is still very experimental
Please do not rely on it for production use, but feel free to use it and file issues
""")
  go_toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]
  # First gather all the library rules
  golibs = depset()
  for dep in ctx.attr.deps:
    golib = dep[GoLibrary]
    golibs += [golib]
    golibs += golib.transitive

  # Now scan them for sources
  seen_libs = {}
  seen_paths = {}
  outputs = depset()
  packages = []
  for golib in golibs:
    if golib.importpath in seen_libs:
      # We found two different library rules that map to the same import path
      # This is legal in bazel, but we can't build a valid go path for it.
      # TODO: we might be able to ignore this if the content is identical
      print("""Duplicate package
Found {} in
  {}
and
  {}
""".format(golib.importpath, golib.label, seen_libs[golib.importpath].label))
      # for now we don't fail if we see duplicate packages
      # the most common case is the same source from two different workspaces
      continue
    seen_libs[golib.importpath] = golib
    package_files = []
    outdir = "{}/src/{}".format(ctx.label.name, golib.importpath)
    for src in golib.srcs:
      outpath = "{}/{}".format(outdir, src.basename)
      if outpath in seen_paths:
        # If we see the same path twice, it's a fatal error
        fail("Duplicate path {}".format(outpath))
      seen_paths[outpath] = True
      out = ctx.new_file(outpath)
      package_files += [out]
      outputs += [out]
      if ctx.attr.mode == "copy":
        ctx.template_action(template=src, output=out, substitutions={})
      elif ctx.attr.mode == "link":
        ctx.action(
            command='ln -s $(readlink "$1") "$2"',
            arguments=[src.path, out.path],
            inputs=[src],
            outputs=[out],
        )
      else:
        fail("Invalid go path mode '{}'".format(ctx.attr.mode))
    packages += [struct(
      golib = golib,
      dir = outdir,
      files = package_files,
    )]
  envscript = ctx.new_file("{}/setenv.sh".format(ctx.label.name))
  gopath, _, _ = envscript.short_path.rpartition("/")
  ctx.file_action(envscript, content="""
export GOROOT="{goroot}"
export GOPATH="$(pwd)/{gopath}")
""".format(
      goroot=go_toolchain.paths.root.path,
      gopath = gopath,
  ))
  return [
      DefaultInfo(
          files = outputs + [envscript],
      ),
      GoPath(
        gopath = gopath,
        packages = packages,
        srcs = outputs,
      )
  ]

go_path = rule(
    _go_path_impl,
    attrs = {
        "deps": attr.label_list(providers=[GoLibrary]),
        "mode": attr.string(default="copy", values=["link", "copy"]),
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)