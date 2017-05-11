# Copyright 2016 The Bazel Go Rules Authors. All rights reserved.
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
""" Rules to support automatic formatting of bzl files
"""


def _bzl_format_yapf_repository_impl(ctx):
  ctx.download_and_extract(
      url =
      "https://codeload.github.com/google/yapf/zip/021238214778cf6bcce04dff3bef1f3f0da15530",
      stripPrefix = "yapf-021238214778cf6bcce04dff3bef1f3f0da15530",
      type = "zip")
  ctx.file("BUILD", """
alias(
    name="yapf",
    actual="//yapf:yapf",
    visibility = ["//visibility:public"],
)
""")
  ctx.file("yapf/BUILD", """
py_binary(
    name="yapf",
    srcs=glob(["**/*.py"]),
    main="__main__.py",
    visibility = ["//visibility:public"],
)""")


_bzl_format_yapf_repository = repository_rule(
    implementation = _bzl_format_yapf_repository_impl,
    attrs = {})


def bzl_format_repositories():
  _bzl_format_yapf_repository(name = "bzl_format_yapf")


def _run_yapf_impl(ctx):
  run_script = ctx.new_file("run_yapf.sh")
  yapf = ctx.attr.yapf.files_to_run.executable.short_path
  ctx.file_action(
      run_script,
      content = "\n".join([
          "BASE=$(dirname $(readlink WORKSPACE))",
          "find $BASE -name *.bzl -exec " + yapf +
          " -i --style='{based_on_style: chromium, spaces_around_default_or_named_assign: True}' {} \\; ",
          "",
      ]))
  return struct(files = depset([run_script]))


_run_yapf = rule(
    _run_yapf_impl,
    attrs = {
        "yapf": attr.label(),
    })


def bzl_format_rules():
  _run_yapf(
      name = "run_yapf",
      yapf = "@bzl_format_yapf//:yapf",
      visibility = ["//visibility:private"])
  native.sh_binary(
      name = "bzl_format",
      data = [
          "//:WORKSPACE",
          "@bzl_format_yapf//:yapf",
      ],
      srcs = [":run_yapf"],
      visibility = ["//visibility:private"])
