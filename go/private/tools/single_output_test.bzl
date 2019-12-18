# Copyright 2017 The Bazel Go Rules Authors. All rights reserved.
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

def _impl(ctx):
    exe = ctx.outputs.out
    ctx.actions.write(
        output = exe,
        # The file must not be empty because running an empty .bat file as a
        # subprocess fails on Windows, so we write one space to it.
        content = " ",
        is_executable = True,
    )
    return [DefaultInfo(files = depset([exe]), executable = exe)]

_single_output_test = rule(
    implementation = _impl,
    attrs = {
        "dep": attr.label(allow_single_file = True),
        "out": attr.output(),
    },
    test = True,
)

def single_output_test(name, dep, **kwargs):
    """Checks that a dependency produces a single output file.

    This test works by setting `allow_single_file = True` on the `dep` attribute.
    If `dep` provides zero or multiple files in its `files` provider, Bazel will
    fail to build this rule during analysis. The actual test does nothing.

    Args:
      name: The name of the test rule.
      dep: a label for the rule to check.
      **kwargs: The <a href="https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes-tests">common attributes for tests</a>.
    """

    _single_output_test(
        name = name,
        dep = dep,
        # On Windows we need the ".bat" extension.
        # On other platforms the extension doesn't matter.
        # Therefore we can use ".bat" on every platform.
        out = name + ".bat",
        **kwargs
    )
