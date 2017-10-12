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

def action_with_go_env(ctx, go_toolchain, executable = None, command=None, arguments = [], inputs = [], **kwargs):
  if command:
    fail("You cannot run action_with_go_env with a 'command', only an 'executable'")
  args = [
      "-go", go_toolchain.tools.go.path,
      "-root_file", go_toolchain.stdlib.root_file.path,
      "-goos", go_toolchain.stdlib.goos,
      "-goarch", go_toolchain.stdlib.goarch,
      "-cgo=" + ("1" if go_toolchain.stdlib.cgo else "0"),
  ] + arguments
  ctx.action(
      inputs = depset(inputs) + go_toolchain.data.tools + [go_toolchain.stdlib.root_file] + go_toolchain.stdlib.libs,
      executable = executable,
      arguments = args,
      **kwargs)

def bootstrap_action(ctx, go_toolchain, inputs, outputs, mnemonic, arguments):
  ctx.actions.run_shell(
    inputs = inputs + go_toolchain.data.tools + go_toolchain.stdlib.libs,
    outputs = outputs,
    mnemonic = mnemonic,
    command = "export GOROOT=$(pwd)/{} && {} {}".format(go_toolchain.stdlib.root_file.dirname, go_toolchain.tools.go.path, " ".join(arguments)),
  )
