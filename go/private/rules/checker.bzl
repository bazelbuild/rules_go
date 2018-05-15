# Copyright 2018 The Bazel Authors. All rights reserved.
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

load(
    "@io_bazel_rules_go//go/private:context.bzl",
    "go_context",
    "EXPORT_PATH",
)
load(
    "@io_bazel_rules_go//go/private:rules/rule.bzl",
    "go_rule",
)
load(
    "@io_bazel_rules_go//go/private:providers.bzl",
    "GoArchive",
    "GoLibrary",
    "GoChecker",
    "get_archive"
)

def _go_checker_impl(ctx):
  # Generate the source for the checker binary.
  go = go_context(ctx)
  checker_main = go.declare_file(go, "checker_main.go")
  checker_args = ctx.actions.args()
  checker_args.add(['-output', checker_main])
  check_archives = [get_archive(dep) for dep in ctx.attr.deps]
  check_importpaths = [archive.data.importpath for archive in check_archives]
  checker_args.add(check_importpaths, before_each="-check_importpath")
  if ctx.file.config:
    checker_args.add(['-config', ctx.file.config])
  ctx.actions.run(
      outputs = [checker_main],
      mnemonic = "GoGenChecker",
      executable = go.builders.checker_generator,
      arguments = [checker_args],
  )

  # Compile the checker binary itself.
  checker_library = GoLibrary(
      name = go._ctx.label.name + "~checker",
      label = go._ctx.label,
      importpath = "checkermain",
      importmap = "checkermain",
      pathtype = EXPORT_PATH,
      resolve = None,
  )

  checker_source = go.library_to_source(go, struct(
      srcs = [struct(files=[checker_main])],
      embed = [ctx.attr._checker_srcs],
      deps = check_archives,
  ), checker_library, False)
  checker_archive, executable, runfiles = go.binary(go,
      name = ctx.label.name,
      source = checker_source,
  )
  return [
      GoChecker(checker = executable),
      DefaultInfo(
          files = depset([executable]),
          runfiles = checker_archive.runfiles,
          executable = executable,
      ),
  ]

go_checker = go_rule(
    _go_checker_impl,
    bootstrap_attrs = [
        "_builders",
        "_stdlib",
    ],
    attrs = {
        "deps": attr.label_list(
            providers = [GoArchive],
            # TODO(samueltan): make this attribute mandatory.
        ),
        "config": attr.label(
            allow_single_file = True,
        ),
        "_analysis": attr.label(
            default = "@io_bazel_rules_go//go/tools/analysis:analysis",
        ),
        "_gcexportdata": attr.label(
            default = "@io_bazel_rules_go//vendor/golang.org/x/tools/go/gcexportdata:go_default_library",
        ),
        "_checker_srcs": attr.label(
            default = "@io_bazel_rules_go//go/tools/builders:checker_srcs",
        ),
    },
    executable = True,
)
