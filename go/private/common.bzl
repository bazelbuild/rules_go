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
    ".h",
]

cxx_exts = [
    ".cc",
    ".cxx",
    ".cpp",
    ".h",
    ".hh",
    ".hpp",
    ".hxx",
]

objc_exts = [
    ".m",
    ".mm",
    ".h",
    ".hh",
    ".hpp",
    ".hxx",
]

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
    sources = struct(
        go = [],
        asm = [],
        headers = [],
        c = [],
        cxx = [],
        objc = [],
    )
    ext_pairs = (
        (sources.go, go_exts),
        (sources.headers, hdr_exts),
        (sources.asm, asm_exts),
        (sources.c, c_exts),
        (sources.cxx, cxx_exts),
        (sources.objc, objc_exts),
    )
    extmap = {}
    for outs, exts in ext_pairs:
        for ext in exts:
            ext = ext[1:]  # strip the dot
            if ext in extmap:
                break
            extmap[ext] = outs
    for src in as_iterable(srcs):
        extouts = extmap.get(src.extension)
        if extouts == None:
            fail("Unknown source type {0}".format(src.basename))
        extouts.append(src)
    return sources

def join_srcs(source):
    return source.go + source.headers + source.asm + source.c + source.cxx + source.objc

def env_execute(ctx, arguments, environment = {}, **kwargs):
    """env_executes a command in a repository context. It prepends "env -i"
    to "arguments" before calling "ctx.execute".

    Variables that aren't explicitly mentioned in "environment"
    are removed from the environment. This should be preferred to "ctx.execut"e
    in most situations.
    """
    if ctx.os.name.startswith("windows"):
        return ctx.execute(arguments, environment = environment, **kwargs)
    env_args = ["env", "-i"]
    environment = dict(environment)
    for var in ["TMP", "TMPDIR"]:
        if var in ctx.os.environ and not var in environment:
            environment[var] = ctx.os.environ[var]
    for k, v in environment.items():
        env_args.append("%s=%s" % (k, v))
    arguments = env_args + arguments
    return ctx.execute(arguments, **kwargs)

def executable_extension(ctx):
    extension = ""
    if ctx.os.name.startswith("windows"):
        extension = ".exe"
    return extension

def goos_to_extension(goos):
    if goos == "windows":
        return ".exe"
    return ""

ARCHIVE_EXTENSION = ".a"

SHARED_LIB_EXTENSIONS = [".dll", ".dylib", ".so"]

def goos_to_shared_extension(goos):
    return {
        "windows": ".dll",
        "darwin": ".dylib",
    }.get(goos, ".so")

MINIMUM_BAZEL_VERSION = "0.8.0"

def as_list(v):
    if type(v) == "list":
        return v
    if type(v) == "tuple":
        return list(v)
    if type(v) == "depset":
        return v.to_list()
    fail("as_list failed on {}".format(v))

def as_iterable(v):
    if type(v) == "list":
        return v
    if type(v) == "tuple":
        return v
    if type(v) == "depset":
        return v.to_list()
    fail("as_iterator failed on {}".format(v))

def as_tuple(v):
    if type(v) == "tuple":
        return v
    if type(v) == "list":
        return tuple(v)
    if type(v) == "depset":
        return tuple(v.to_list())
    fail("as_tuple failed on {}".format(v))

def as_set(v):
    if type(v) == "depset":
        return v
    if type(v) == "list":
        return depset(v)
    if type(v) == "tuple":
        return depset(v)
    fail("as_tuple failed on {}".format(v))
