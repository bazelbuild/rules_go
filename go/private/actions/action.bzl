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

def action_with_go_env(ctx, go_toolchain, env=None, **kwargs):
  fullenv = {
      "GOROOT": go_toolchain.stdlib.root.path,
      "GOOS": go_toolchain.stdlib.goos,
      "GOARCH": go_toolchain.stdlib.goarch,
      "TMP": go_toolchain.paths.tmp,
  }
  if env:
    fullenv.update(env)
  ctx.action(env=fullenv, **kwargs)