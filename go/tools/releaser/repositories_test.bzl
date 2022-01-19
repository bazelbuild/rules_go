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

# Once nested repositories work, this file should cease to exist.

def go_rules_dependencies():
    # releaser:upgrade-dep golang tools
    repo_rule(
        expected = [
            "//third_party:org_golang_x_tools-gazelle.patch",
            "//third_party:org_golang_x_tools-gazelle.patch",
            "//third_party:org_golang_x_tools-gazelle.patch",
            "@io_bazel_rules_go//third_party:org_golang_x_tools-gazelle.patch",
            "invalid patch function: NotLabel",
            "invalid patch function: NotLabel",
            "not all patches are string literals or Label()",
            "Label expr should have 1 argument, found 2",
            "Label expr does not contain a string literal",
        ],
        patches = [
            # releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/tools -go_naming_convention import_alias
            Label("//third_party:org_golang_x_tools-gazelle.patch"),
            # releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/tools -go_naming_convention import_alias
            "@io_bazel_rules_go//third_party:org_golang_x_tools-gazelle.patch",
            # releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/tools -go_naming_convention import_alias
            "//third_party:org_golang_x_tools-gazelle.patch",
            # releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/tools -go_naming_convention import_alias
            Label("@io_bazel_rules_go//third_party:org_golang_x_tools-gazelle.patch"),
            # releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/tools -go_naming_convention import_alias
            NotLabel("//third_party:org_golang_x_tools-gazelle.patch"),
            # releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/tools -go_naming_convention import_alias
            NotLabel(True),
            # releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/tools -go_naming_convention import_alias
            True,
            # releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/tools -go_naming_convention import_alias
            Label("//third_party:org_golang_x_tools-gazelle.patch", True),
            # releaser:patch-cmd gazelle -repo_root . -go_prefix golang.org/x/tools -go_naming_convention import_alias
            Label(True),
        ],
    )
