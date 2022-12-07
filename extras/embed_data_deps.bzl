# Copyright 2019 The Bazel Authors. All rights reserved.
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

"""Repository dependencies for embed_data.bzl"""

load(
    "@bazel_tools//tools/build_defs/repo:git.bzl",
    "git_repository",
)

def go_embed_data_dependencies():
    print("Embedding is now better handled by using rules_go's built-in embedding functionality (https://github.com/bazelbuild/rules_go/blob/master/docs/go/core/rules.md#go_library-embedsrcs). The `go_embed_data_dependencies` macro is deprecated and will be removed in rules_go version 0.39.")

    if "com_github_kevinburke_go_bindata" not in native.existing_rules():
        git_repository(
            name = "com_github_kevinburke_go_bindata",
            remote = "https://github.com/kevinburke/go-bindata",
            # v3.13.0+incompatible, "latest" as of 2019-07-08
            commit = "53d73b98acf3bd9f56d7f9136ed8e1be64756e1d",
            patches = [Label("//third_party:com_github_kevinburke_go_bindata-gazelle.patch")],
            patch_args = ["-p1"],
            shallow_since = "1545009224 +0000",
            # gazelle args: -go_prefix github.com/kevinburke/go-bindata
        )
