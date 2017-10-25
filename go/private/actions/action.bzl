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

def action_with_go_env(ctx, go_toolchain, mode, executable = None, command=None, arguments = [], inputs = [], **kwargs):
  if command:
    fail("You cannot run action_with_go_env with a 'command', only an 'executable'")
  stdlib = go_toolchain.stdlib.get(ctx, go_toolchain, mode)
  args = [
      "-go", stdlib.go.path,
      "-root_file", stdlib.root_file.path,
      "-goos", stdlib.goos,
      "-goarch", stdlib.goarch,
      "-cgo=" + ("0" if mode.pure else "1"),
  ] + arguments
  ctx.action(
      inputs = depset(inputs) + stdlib.files,
      executable = executable,
      arguments = args,
      **kwargs)

def bootstrap_action(ctx, go_toolchain, inputs, outputs, mnemonic, arguments):
  stdlib = go_toolchain.stdlib.cgo
  ctx.actions.run_shell(
    inputs = inputs + stdlib.files,
    outputs = outputs,
    mnemonic = mnemonic,
    command = "export GOROOT=$(pwd)/{} && {} {}".format(stdlib.root_file.dirname, stdlib.go.path, " ".join(arguments)),
  )
