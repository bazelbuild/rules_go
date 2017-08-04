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

load("@io_bazel_rules_go//go/private:common.bzl", "go_exts", "hdr_exts", "asm_exts", "c_exts")

GoSource = provider()
GoLibrary = provider()
GoBinary = provider()


def split_srcs(ctx, srcs):
  go = depset()
  headers = depset()
  asm = depset()
  c = depset()
  for src in srcs:
    if any([src.basename.endswith(ext) for ext in go_exts]):
      go += [src]
    elif any([src.basename.endswith(ext) for ext in hdr_exts]):
      headers += [src]
    elif any([src.basename.endswith(ext) for ext in asm_exts]):
      asm += [src]
    elif any([src.basename.endswith(ext) for ext in c_exts]):
      c += [src]
    else:
      fail("Unknown source type {0} in {1}".format(src.basename, ctx.label))
  return GoSource(
      input = srcs,
      go = go,
      headers = headers,
      asm = asm,
      c = c,
  )
