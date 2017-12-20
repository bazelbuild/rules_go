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

load("@io_bazel_rules_go//go/private:providers.bzl", "GoLibrary")
load("//go/private:skylib/lib/dicts.bzl", "dicts")
load("//go/private:skylib/lib/paths.bzl", "paths")
load("//go/private:skylib/lib/sets.bzl", "sets")
load("//go/private:skylib/lib/shell.bzl", "shell")
load("//go/private:skylib/lib/structs.bzl", "structs")
load("@io_bazel_rules_go//go/private:mode.bzl", "mode_string")

go_exts = [
    ".go",
]

asm_exts = [
    ".s",
    ".S",
    ".h",  # may be included by .s
]

# be consistent to cc_library.
hdr_exts = [
    ".h",
    ".hh",
    ".hpp",
    ".hxx",
    ".inc",
]

c_exts = [
    ".c",
    ".cc",
    ".cxx",
    ".cpp",
    ".h",
    ".hh",
    ".hpp",
    ".hxx",
]

go_filetype = FileType(go_exts + asm_exts)
cc_hdr_filetype = FileType(hdr_exts)

# Extensions of files we can build with the Go compiler or with cc_library.
# This is a subset of the extensions recognized by go/build.
cgo_filetype = FileType(go_exts + asm_exts + c_exts)

def pkg_dir(workspace_root, package_name):
  """Returns a relative path to a package directory from the root of the
  sandbox. Useful at execution-time or run-time."""
  if workspace_root and package_name:
    return workspace_root + "/" + package_name
  if workspace_root:
    return workspace_root
  if package_name:
    return package_name
  return "."

def split_srcs(srcs):
  go = []
  headers = []
  asm = []
  c = []
  for src in srcs:
    if any([src.basename.endswith(ext) for ext in go_exts]):
      go.append(src)
    elif any([src.basename.endswith(ext) for ext in hdr_exts]):
      headers.append(src)
    elif any([src.basename.endswith(ext) for ext in asm_exts]):
      asm.append(src)
    elif any([src.basename.endswith(ext) for ext in c_exts]):
      c.append(src)
    else:
      fail("Unknown source type {0}".format(src.basename))
  return struct(
      go = go,
      headers = headers,
      asm = asm,
      c = c,
  )

def join_srcs(source):
  return source.go + source.headers + source.asm + source.c


def env_execute(ctx, arguments, environment = {}, **kwargs):
  """env_executes a command in a repository context. It prepends "env -i"
  to "arguments" before calling "ctx.execute".

  Variables that aren't explicitly mentioned in "environment"
  are removed from the environment. This should be preferred to "ctx.execut"e
  in most situations.
  """
  if ctx.os.name.startswith('windows'):
    return ctx.execute(arguments, environment=environment, **kwargs)
  env_args = ["env", "-i"]
  environment = dict(environment)
  for var in ["TMP", "TMPDIR"]:
    if var in ctx.os.environ and not var in environment:
      environment[var] = ctx.os.environ[var]
  for k, v in environment.items():
    env_args.append("%s=%s" % (k, v))
  arguments = env_args + arguments
  return ctx.execute(arguments, **kwargs)

def to_set(v):
  if type(v) == "depset":
    fail("Do not pass a depset to to_set")
  return depset(v)

def executable_extension(ctx):
  extension = ""
  if ctx.os.name.startswith('windows'):
    extension = ".exe"
  return extension

def goos_to_extension(goos):
  if goos == "windows":
    return ".exe"
  return ""

MINIMUM_BAZEL_VERSION = "0.8.0"

# _parse_bazel_version and check_version copied from
# github.com/tensorflow/tensorflow/blob/cfd0d3f2aa24b3078d2e79ad0a212c7c53916de9/tensorflow/workspace.bzl

# Parse the bazel version string from `native.bazel_version`.
def _parse_bazel_version(bazel_version):
  # Remove commit from version.
  version = bazel_version.split(" ", 1)[0]
  # Split into (release, date) parts and only return the release
  # as a tuple of integers.
  parts = version.split("-", 1)
  # Turn "release" into a tuple of strings
  version_tuple = ()
  for number in parts[0].split("."):
    version_tuple += (str(number),)
  return version_tuple

# Check that a specific bazel version is being used.
def check_version(bazel_version):
  if "bazel_version" not in dir(native):
    fail("\nCurrent Bazel version is lower than 0.2.1, expected at least %s\n" %
         bazel_version)
  elif not native.bazel_version:
    print("\nCurrent Bazel is not a release version, cannot check for " +
          "compatibility.")
    print("Make sure that you are running at least Bazel %s.\n" % bazel_version)
  else:
    current_bazel_version = _parse_bazel_version(native.bazel_version)
    minimum_bazel_version = _parse_bazel_version(bazel_version)
    if minimum_bazel_version > current_bazel_version:
      fail("\nCurrent Bazel version is {}, expected at least {}\n".format(
          native.bazel_version, bazel_version))
