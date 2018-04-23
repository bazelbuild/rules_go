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
)
load(
    "@io_bazel_rules_go//go/private:rules/rule.bzl",
    "go_rule",
)
load(
    "@io_bazel_rules_go//go/private:providers.bzl",
    "GoArchive",
    "GoLibrary",
    "GoChecker"
)

def _go_checker_impl(ctx):
  # Generate the source for the checker binary.
  go = go_context(ctx)
  checker_main = go.declare_file(go, "checker_main.go")
  checker_args = ctx.actions.args()
  # TODO(samueltan): pass import paths of check libraries to the checker generator.
  checker_args.add(['-output', checker_main, '-config', ctx.file.config])
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
      importpath = "checker",
      importmap = None,
      resolve = None,
  )
  checker_source = go.library_to_source(go, struct(
      srcs = [struct(files=[checker_main])],
  ), checker_library, False)
  checker_archive, executable = go.binary(go,
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
    bootstrap_checker = True,
    attrs = {
        "checks": attr.label_list(
            providers = [GoArchive],
            # TODO(samueltan): make this attribute mandatory.
        ),
        "config": attr.label(
            allow_single_file = True,
        ),
    },
    executable = True,
)
