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

"""These are bare-bones Go rules.

In order of priority:

- No support for build tags

- BUILD file must be written by hand.

- No support for SWIG

- No test sharding or test XML.

"""

_DEFAULT_LIB = "go_default_library"

_VENDOR_PREFIX = "/vendor/"

go_filetype = FileType([".go"])
# be consistent to cc_library.
hdr_exts = ['.h', '.hh', '.hpp', '.hxx', '.inc']
cc_hdr_filetype = FileType(hdr_exts)

################

# In Go, imports are always fully qualified with a URL,
# eg. github.com/user/project. Hence, a label //foo:bar from within a
# Bazel workspace must be referred to as
# "github.com/user/project/foo/bar". To make this work, each rule must
# know the repository's URL. This is achieved, by having all go rules
# depend on a globally unique target that has a "go_prefix" transitive
# info provider.

def _go_prefix_impl(ctx):
  """go_prefix_impl provides the go prefix to use as a transitive info provider."""
  return struct(go_prefix = ctx.attr.prefix)

def _go_prefix(ctx):
  """slash terminated go-prefix"""
  prefix = ctx.attr.go_prefix.go_prefix
  if prefix != "" and not prefix.endswith("/"):
    prefix = prefix + "/"
  return prefix

_go_prefix_rule = rule(
    _go_prefix_impl,
    attrs = {
        "prefix": attr.string(mandatory = True),
    },
)

def go_prefix(prefix):
  """go_prefix sets the Go import name to be used for this workspace."""
  _go_prefix_rule(name = "go_prefix",
    prefix = prefix,
    visibility = ["//visibility:public" ]
  )

################

# TODO(bazel-team): it would be nice if Bazel had this built-in.
def symlink_tree_commands(dest_dir, artifact_dict):
  """Symlink_tree_commands returns a list of commands to create the
  dest_dir, and populate it according to the given dict.

  Args:
    dest_dir: The destination directory, a string.
    artifact_dict: The mapping of exec-path => path in the dest_dir.

  Returns:
    A list of commands that will setup the symlink tree.
  """
  cmds = [
    "rm -rf " + dest_dir,
    "mkdir -p " + dest_dir,
  ]

  for old_path, new_path in artifact_dict.items():
    new_dir = new_path[:new_path.rfind('/')]
    up = (new_dir.count('/') + 1 +
          dest_dir.count('/') + 1)
    cmds += [
      "mkdir -p %s/%s" % (dest_dir, new_dir),
      "ln -s %s%s %s/%s" % ('../' * up, old_path, dest_dir, new_path),
    ]
  return cmds

def go_environment_vars(ctx):
  """Return a map of environment variables for use with actions, based on
  the arguments. Uses the ctx.fragments.cpp.cpu attribute, if present,
  and picks a default of target_os="linux" and target_arch="amd64"
  otherwise.

  Args:
    The skylark Context.

  Returns:
    A dict of environment variables for running Go tool commands that build for
    the target OS and architecture.
  """
  bazel_to_go_toolchain = {"k8": {"GOOS": "linux",
                                  "GOARCH": "amd64"},
                           "piii": {"GOOS": "linux",
                                    "GOARCH": "386"},
                           "darwin": {"GOOS": "darwin",
                                      "GOARCH": "amd64"},
                           "freebsd": {"GOOS": "freebsd",
                                       "GOARCH": "amd64"},
                           "armeabi-v7a": {"GOOS": "linux",
                                           "GOARCH": "arm"},
                           "arm": {"GOOS": "linux",
                                   "GOARCH": "arm"}}
  return bazel_to_go_toolchain.get(ctx.fragments.cpp.cpu,
                                   {"GOOS": "linux",
                                    "GOARCH": "amd64"})

def emit_go_compile_action(ctx, sources, deps, out_lib, cgo_object=None):
  """Construct the command line for compiling Go code.
  Constructs a symlink tree to accomodate for workspace name.

  Args:
    ctx: The skylark Context.
    sources: an iterable of source code artifacts (or CTs? or labels?)
    deps: an iterable of dependencies. Each dependency d should have an
      artifact in d.go_library_object representing an imported library.
    out_lib: the artifact (configured target?) that should be produced
  """
  config_strip = len(ctx.configuration.bin_dir.path) + 1

  out_dir = out_lib.path + ".dir"
  out_depth = out_dir.count('/') + 1
  tree_layout = {}
  inputs = []
  prefix = _go_prefix(ctx)
  import_map = {}
  for d in deps:
    library_artifact_path = d.go_library_object.path[config_strip:]
    tree_layout[d.go_library_object.path] = prefix + library_artifact_path
    inputs += [d.go_library_object]

    source_import = prefix + d.label.package + "/" + d.label.name
    actual_import = prefix + d.label.package + "/" + d.label.name
    if d.label.name == _DEFAULT_LIB:
      source_import = prefix + d.label.package

    if source_import.rfind(_VENDOR_PREFIX) != -1:
      source_import = source_import[len(_VENDOR_PREFIX) + source_import.rfind(_VENDOR_PREFIX):]

    if source_import != actual_import:
      if source_import in import_map:
        fail("duplicate import %s: adding %s and have %s"
             % (source_import, actual_import, import_map[source_import]))
      import_map[source_import] = actual_import

  inputs += list(sources)
  for s in sources:
    tree_layout[s.path] = prefix + s.path

  cmds = symlink_tree_commands(out_dir, tree_layout)
  args = [
      "cd ", out_dir, "&&",
      ('../' * out_depth) + ctx.file.go_tool.path,
      "tool", "compile",
      "-o", ('../' * out_depth) + out_lib.path, "-pack",

      # Import path.
      "-I", "."] + [
        "-importmap=%s=%s" % (k,v) for k, v in import_map.items()
      ]

  # Set -p to the import path of the library, ie.
  # (ctx.label.package + "/" ctx.label.name) for now.
  cmds += [ "export GOROOT=$(pwd)/" + ctx.file.go_tool.dirname + "/..",
    ' '.join(args + cmd_helper.template(sources, prefix + "%{path}"))]
  extra_inputs = ctx.files.toolchain

  if cgo_object:
    cmds += ["cd " + ('../' * out_depth),
             (ctx.file.go_tool.path + " tool pack r " +
              out_lib.path + " " + cgo_object.cgo_obj.path)]
    extra_inputs += [cgo_object.cgo_obj]

  ctx.action(
      inputs = inputs + extra_inputs,
      outputs = [out_lib],
      mnemonic = "GoCompile",
      command =  " && ".join(cmds),
      env = go_environment_vars(ctx))

def go_library_impl(ctx):
  """Implements the go_library() rule."""

  sources = set(ctx.files.srcs)
  deps = ctx.attr.deps

  cgo_object = None
  if hasattr(ctx.attr, "cgo_object"):
    cgo_object = ctx.attr.cgo_object

  if ctx.attr.library:
    sources += ctx.attr.library.go_sources
    deps += ctx.attr.library.direct_deps
    if ctx.attr.library.cgo_object:
      if cgo_object:
        fail("go_library %s cannot have cgo_object because the package " +
             "already has cgo_object in %s" % (ctx.label.name,
                                               ctx.attr.library.name))
      cgo_object = ctx.attr.library.cgo_object

  if not sources:
    fail("may not be empty", "srcs")

  transitive_cgo_deps = set([], order="link")
  if cgo_object:
    transitive_cgo_deps += cgo_object.cgo_deps

  out_lib = ctx.outputs.lib
  emit_go_compile_action(ctx, set(sources), deps, out_lib,
                         cgo_object=cgo_object)

  transitive_libs = set([out_lib])
  for dep in ctx.attr.deps:
     transitive_libs += dep.transitive_go_library_object
     transitive_cgo_deps += dep.transitive_cgo_deps

  dylibs = []
  if cgo_object:
    dylibs += [d for d in cgo_object.cgo_deps if d.path.endswith(".so")]

  runfiles = ctx.runfiles(files = dylibs, collect_data = True)
  return struct(
    label = ctx.label,
    files = set([out_lib]),
    direct_deps = deps,
    runfiles = runfiles,
    go_sources = sources,
    go_library_object = out_lib,
    transitive_go_library_object = transitive_libs,
    cgo_object = cgo_object,
    transitive_cgo_deps = transitive_cgo_deps,
  )

def _c_linker_options(ctx, blacklist=[]):
  """Extracts flags to pass to $(CC) on link from the current context

  Args:
    ctx: the current context
    blacklist: Any flags starts with any of these prefixes are filtered out from
      the return value.

  Returns:
    A list of command line flags
  """
  cpp = ctx.fragments.cpp
  features = ctx.features
  options = cpp.compiler_options(features)
  options += cpp.unfiltered_compiler_options(features)
  options += cpp.link_options
  options += cpp.mostly_static_link_options(ctx.features, False)
  filtered = []
  for opt in options:
    if any([opt.startswith(prefix) for prefix in blacklist]):
      continue
    filtered.append(opt)
  return filtered

def emit_go_link_action(ctx, transitive_libs, lib, executable, cgo_deps):
  """Sets up a symlink tree to libraries to link together."""
  out_dir = executable.path + ".dir"
  out_depth = out_dir.count('/') + 1
  tree_layout = {}

  config_strip = len(ctx.configuration.bin_dir.path) + 1
  out = executable.path[config_strip:]
  prefix = _go_prefix(ctx)

  for l in transitive_libs:
    library_artifact_path = l.path[config_strip:]
    tree_layout[l.path] = prefix + library_artifact_path

  for d in cgo_deps:
    tree_layout[d.path] = d.short_path

  tree_layout[lib.path] = prefix + lib.path[config_strip:]

  ld = "%s" % ctx.fragments.cpp.compiler_executable
  if ld[0] != '/':
    ld = ('../' * out_depth) + ld
  ldflags = _c_linker_options(ctx) + [
      "-Wl,-rpath,$ORIGIN/" + ("../" * (out.count("/") + 1)),
      "-L" + prefix,
  ]
  cmds = symlink_tree_commands(out_dir, tree_layout)
  cmds += [
    "export GOROOT=$(pwd)/" + ctx.file.go_tool.dirname + "/..",
    "cd " + out_dir,
    ' '.join([
      ('../' * out_depth) + ctx.file.go_tool.path,
      "tool", "link", "-L", ".",
      "-o", prefix + out,
      "-s",
      "-extld", ld,
      "-extldflags", "'" + " ".join(ldflags), "'",
      prefix + lib.path[config_strip:]]),
    "mv -f " + prefix + out + " " + ("../" * out_depth) + executable.path,
  ]

  ctx.action(
      inputs = (list(transitive_libs) + [lib] +
                list(cgo_deps) + ctx.files.toolchain),
      outputs = [executable],
      command = ' && '.join(cmds),
      mnemonic = "GoLink",
      env = go_environment_vars(ctx))

def go_binary_impl(ctx):
  """go_binary_impl emits actions for compiling and linking a go executable."""
  lib_result = go_library_impl(ctx)
  executable = ctx.outputs.executable
  lib_out = ctx.outputs.lib

  emit_go_link_action(
    ctx, lib_result.transitive_go_library_object, lib_out, executable,
    lib_result.transitive_cgo_deps)

  runfiles = ctx.runfiles(collect_data = True,
                          files = ctx.files.data)
  return struct(files = set([executable]) + lib_result.files,
                runfiles = runfiles,
                cgo_object = lib_result.cgo_object)

def go_test_impl(ctx):
  """go_test_impl implements go testing.

  It emits an action to run the test generator, and then compiles the
  test into a binary."""

  lib_result = go_library_impl(ctx)
  main_go = ctx.outputs.main_go
  prefix = _go_prefix(ctx)

  go_import = prefix + ctx.label.package + "/" + ctx.label.name

  args = (["--package", go_import, "--output", ctx.outputs.main_go.path] +
          cmd_helper.template(lib_result.go_sources, "%{path}"))

  inputs = list(lib_result.go_sources) + list(ctx.files.toolchain)
  ctx.action(
      inputs = inputs,
      executable = ctx.executable.test_generator,
      outputs = [main_go],
      mnemonic = "GoTestGenTest",
      arguments = args,
      env = dict(go_environment_vars(ctx), RUNDIR=ctx.label.package))

  emit_go_compile_action(
    ctx, set([main_go]), ctx.attr.deps + [lib_result], ctx.outputs.main_lib)

  emit_go_link_action(
    ctx, lib_result.transitive_go_library_object,
    ctx.outputs.main_lib, ctx.outputs.executable,
    lib_result.transitive_cgo_deps)

  # TODO(bazel-team): the Go tests should do a chdir to the directory
  # holding the data files, so open-source go tests continue to work
  # without code changes.
  runfiles = ctx.runfiles(collect_data = True,
                          files = (ctx.files.data + [ctx.outputs.executable] +
                                   list(lib_result.runfiles.files)))
  return struct(runfiles=runfiles)

go_env_attrs = {
    "toolchain": attr.label(
        default = Label("//go/toolchain:toolchain"),
        allow_files = True,
        cfg = HOST_CFG,
    ),
    "go_tool": attr.label(
        default = Label("//go/toolchain:go_tool"),
        single_file = True,
        allow_files = True,
        cfg = HOST_CFG,
    ),
    "go_prefix": attr.label(
        providers = ["go_prefix"],
        default = Label(
            "//:go_prefix",
            relative_to_caller_repository = True,
        ),
        allow_files = False,
        cfg = HOST_CFG,
    ),
}

go_library_attrs = go_env_attrs + {
    "data": attr.label_list(
        allow_files = True,
        cfg = DATA_CFG,
    ),
    "srcs": attr.label_list(allow_files = go_filetype),
    "deps": attr.label_list(
        providers = [
            "direct_deps",
            "go_library_object",
            "transitive_go_library_object",
            "transitive_cgo_deps",
        ],
    ),
    "library": attr.label(
        providers = ["go_sources", "cgo_object"],
    ),
}

go_library_outputs = {
    "lib": "%{name}.a",
}

go_library = rule(
    go_library_impl,
    attrs = go_library_attrs + {
        "cgo_object": attr.label(
            providers = ["cgo_obj", "cgo_deps"],
        ),
    },
    fragments = ["cpp"],
    outputs = go_library_outputs,
)

go_binary = rule(
    go_binary_impl,
    attrs = go_library_attrs + {
        "stamp": attr.bool(default = False),
    },
    executable = True,
    fragments = ["cpp"],
    outputs = go_library_outputs,
)

go_test = rule(
    go_test_impl,
    attrs = go_library_attrs + {
        "test_generator": attr.label(
            executable = True,
            default = Label(
                "//go/tools:generate_test_main",
            ),
            cfg = HOST_CFG,
        ),
    },
    executable = True,
    fragments = ["cpp"],
    outputs = {
        "lib": "%{name}.a",
        "main_lib": "%{name}_main_test.a",
        "main_go": "%{name}_main_test.go",
    },
    test = True,
)

def _cgo_codegen_impl(ctx):
  out_dir = ctx.label.package + "/" + ctx.attr.outdir
  pkg_depth = ctx.label.package.count("/") + 1

  inputs = ctx.files.srcs + ctx.files.c_hdrs + ctx.files.toolchain
  linkopts = ctx.attr.linkopts
  deps = set([], order="link")

  for d in ctx.attr.deps:
    inputs += list(d.cc.transitive_headers)

    if ctx.fragments.cpp.cpu == 'darwin':
      linkopts += ["-Wl," + lib.short_path for lib in d.cc.libs]
    else:
      linkopts += ["-l:" + lib.short_path for lib in d.cc.libs]
    linkopts += d.cc.link_flags
    deps += d.cc.libs

  cc = ctx.fragments.cpp.compiler_executable
  copts = ctx.fragments.cpp.c_options + ctx.attr.copts
  cmds = [
      "export GOROOT=$(pwd)/" + ctx.file.go_tool.dirname + "/..",
      # We cannot use env for CC because $(CC) on OSX is relative
      # and '../' does not work fine due to symlinks.
      "export CC=$(cd $(dirname {cc}); pwd)/$(basename {cc})".format(cc=cc),
      "export CXX=$CC",
      "objdir=$(pwd)/" + ctx.outputs.outs[0].dirname,
      "mkdir -p $objdir",
      "cd " + ctx.label.package,
      ' '.join(["$GOROOT/bin/go", "tool", "cgo", "-objdir", "$objdir", "--"] +
               copts + [f.label.name for f in ctx.attr.srcs]),
      "rm -f $objdir/_cgo_.o $objdir/_cgo_flags"]
  ctx.action(
      inputs = inputs,
      outputs = ctx.outputs.outs,
      mnemonic = "CGoCodeGen",
      progress_message = "CGoCodeGen %s" % ctx.label,
      command = " && ".join(cmds),
      env = go_environment_vars(ctx) + {
          "CGO_LDFLAGS": " ".join(linkopts),
      },
  )
  return struct(
      label = ctx.label,
      files = set(ctx.outputs.outs),
      cgo_deps = deps,
  )

_cgo_codegn_rule = rule(
    _cgo_codegen_impl,
    attrs = go_env_attrs + {
        "srcs": attr.label_list(
            allow_files = go_filetype,
            non_empty = True,
        ),
        "c_hdrs": attr.label_list(
            allow_files = cc_hdr_filetype,
        ),
        "deps": attr.label_list(
            allow_files = False,
            providers = ["cc"],
        ),
        "copts": attr.string_list(),
        "linkopts": attr.string_list(),
        "outdir": attr.string(mandatory = True),

        "outs": attr.output_list(
            mandatory = True,
            non_empty = True,
        ),
    },
    fragments = ["cpp"],
    output_to_genfiles = True,
)

def _cgo_codegen(name, srcs, c_hdrs=[], deps=[], linkopts=[],
                 go_tool=None, toolchain=None):
  """Generates glue codes for interop between C and Go

  Args:
    name: A unique name of the rule
    srcs: list of Go source files.
      Each of them must contain `import "C"`.
    c_hdrs: C/C++ header files necessary to determine kinds of
      C/C++ identifiers in srcs.
    deps: A list of cc_library rules.
      The generated codes are expected to be linked with these deps.
    linkopts: A list of linker options,
      These flags are passed to the linker when the generated codes
      are linked into the target binary.
  """
  outdir = name + ".dir"

  go_thunks = []
  c_thunks = []
  for s in srcs:
    if not s.endswith('.go'):
      fail("not a .go file: %s" % s)
    stem = s[:-3]
    go_thunks.append(outdir + "/" + stem + ".cgo1.go")
    c_thunks.append(outdir + "/" + stem + ".cgo2.c")

  outs = struct(
      name = name,

      outdir = outdir,
      go_thunks = go_thunks,
      c_thunks = c_thunks,
      c_exports = [
          outdir + "/_cgo_export.c",
          outdir + "/_cgo_export.h",
          ],
      c_dummy = outdir + "/_cgo_main.c",
      gotypes = outdir + "/_cgo_gotypes.go",
  )

  _cgo_codegn_rule(
      name = name,
      srcs = srcs,
      c_hdrs = c_hdrs,
      deps = deps,
      linkopts = linkopts,

      go_tool = go_tool,
      toolchain = toolchain,

      outdir = outdir,
      outs = outs.go_thunks + outs.c_thunks + outs.c_exports + [
          outs.c_dummy, outs.gotypes,
          ],

      visibility = ["//visibility:private"],
      )
  return outs

def _cgo_import_impl(ctx):
  cmds = [
      ("export GOROOT=$(pwd)/" + ctx.file.go_tool.dirname + "/.."),
      (ctx.file.go_tool.path + " tool cgo" +
       " -dynout " + ctx.outputs.out.path +
       " -dynimport " + ctx.file.cgo_o.path +
       " -dynpackage $(%s %s)"  % (ctx.executable._extract_package.path,
                                   ctx.file.sample_go_src.path)),
  ]
  ctx.action(
      inputs = (ctx.files.toolchain +
                [ctx.file.go_tool, ctx.executable._extract_package,
                 ctx.file.cgo_o, ctx.file.sample_go_src]),
      outputs = [ctx.outputs.out],
      command = " && ".join(cmds),
      mnemonic = "CGoImportGen",
  )
  return struct(
      files = set([ctx.outputs.out]),
  )

_cgo_import = rule(
    _cgo_import_impl,
    attrs = go_env_attrs + {
        "cgo_o": attr.label(
            allow_files = True,
            single_file = True,
        ),
        "sample_go_src": attr.label(
            allow_files = True,
            single_file = True,
        ),

        "out": attr.output(
            mandatory = True,
        ),

        "_extract_package": attr.label(
            default = Label("//go/tools/extract_package"),
            executable = True,
            cfg = HOST_CFG,
        ),
    },
)
"""Generates symbol-import directives for cgo

Args:
  cgo_o: The loadable object to extract dynamic symbols from.
  sample_go_src: A go source which is compiled together with the generated file.
    The generated file will have the same Go package name as this file.
  out: Destination of the generated codes.
"""

def _cgo_object_impl(ctx):
  arguments = _c_linker_options(ctx, blacklist=[
      # never link any dependency libraries
      "-l", "-L",
      # manage flags to ld(1) by ourselves
      "-Wl,"])
  arguments += [
      "-o", ctx.outputs.out.path,
      "-nostdlib",
      "-Wl,-r",
  ]
  if ctx.fragments.cpp.cpu == "darwin":
    arguments += ["-shared", "-Wl,-all_load"]
  else:
    arguments += ["-Wl,-whole-archive"]

  lo = ctx.files.src[-1]
  arguments += [lo.path]

  ctx.action(
      inputs = [lo],
      outputs = [ctx.outputs.out],
      mnemonic = "CGoObject",
      progress_message = "Linking %s" % ctx.outputs.out.short_path,
      executable = ctx.fragments.cpp.compiler_executable,
      arguments = arguments,
  )
  return struct(
      files = set([ctx.outputs.out]),
      cgo_obj = ctx.outputs.out,
      cgo_deps = ctx.attr.cgogen.cgo_deps,
  )

_cgo_object = rule(
    _cgo_object_impl,
    attrs = {
        "src": attr.label(
            mandatory = True,
            providers = ["cc"],
        ),
        "cgogen": attr.label(
            mandatory = True,
            providers = ["cgo_deps"],
        ),

        "out": attr.output(
            mandatory = True,
         )
    },
    fragments = ["cpp"],
)
"""Generates _all.o to be archived together with Go objects.

Args:
  src: source static library which contains objects
  cgogen: _cgo_codegen rule which knows the dependency cc_library() rules
    to be linked together with src when we generate the final go binary.
"""

def cgo_library(name, srcs,
                toolchain=None,
                go_tool=None,
                copts=[],
                linkopts=[],
                deps=[],
                **kwargs):
  """Builds a cgo-enabled go library.

  Args:
    name: A unique name for this rule.
    srcs: List of Go, C and C++ files that are processed to build a Go library.
      Those Go files must contain `import "C"`.
      C and C++ files can be anything allowed in `srcs` attribute of `cc_library`.
    copts: Add these flags to the C++ compiler.
    linkopts: Add these flags to the C++ linker.
    deps: List of C/C++ libraries to be linked into the binary target.
      They must be `cc_library` rules.
    data: List of files needed by this rule at runtime.

  NOTE:
    `srcs` cannot contain pure-Go files, which do not have `import "C"`.
    So you need to define another `go_library` when you build a go package with
    both cgo-enabled and pure-Go sources.

    ```
    cgo_library(
        name = "cgo-enabled",
        srcs = ["cgo-enabled.go", "foo.cc", "bar.S", "baz.a"],
    )

    go_library(
        name = "go_default_library",
        srcs = ["pure-go.go"],
        library = ":cgo_enabled",
    )
    ```
  """
  go_srcs = [s for s in srcs if s.endswith('.go')]
  c_hdrs = [s for s in srcs if any([s.endswith(ext) for ext in hdr_exts])]
  c_srcs = [s for s in srcs if not s in (go_srcs + c_hdrs)]

  cgogen = _cgo_codegen(
      name = name + ".cgo",
      srcs = go_srcs,
      c_hdrs = c_hdrs,
      deps = deps,
      linkopts = linkopts,
      go_tool = go_tool,
      toolchain = toolchain,
  )

  # Bundles objects into an archive so that _cgo_.o and _all.o can share them.
  native.cc_library(
      name = cgogen.outdir + "/_cgo_lib",
      srcs = cgogen.c_thunks + cgogen.c_exports + c_srcs + c_hdrs,
      deps = deps,
      copts = copts + [
          "-I", PACKAGE_NAME,
          "-I", "$(GENDIR)/" + PACKAGE_NAME + "/" + cgogen.outdir,
          # The generated thunks often contain unused variables.
          "-Wno-unused-variable",
      ],
      linkopts = linkopts,
      linkstatic = 1,
      # _cgo_.o and _all.o keep all objects in this archive.
      # But it should not be very annoying in the final binary target
      # because _cgo_object rule does not propagate alwayslink=1
      alwayslink = 1,
      visibility = ["//visibility:private"],
  )

  # Loadable object which cgo reads when it generates _cgo_import.go
  native.cc_binary(
      name = cgogen.outdir + "/_cgo_.o",
      srcs = [cgogen.c_dummy],
      deps = deps + [cgogen.outdir + "/_cgo_lib"],
      copts = copts,
      linkopts = linkopts,
      visibility = ["//visibility:private"],
  )
  _cgo_import(
      name = "%s.cgo.importgen" % name,
      cgo_o = cgogen.outdir + "/_cgo_.o",
      out = cgogen.outdir + "/_cgo_import.go",
      sample_go_src = srcs[0],
      go_tool = go_tool,
      toolchain = toolchain,
      visibility = ["//visibility:private"],
  )

  _cgo_object(
      name = cgogen.outdir + "/_cgo_object",
      src = cgogen.outdir + "/_cgo_lib",
      out = cgogen.outdir + "/_all.o",
      cgogen = cgogen.name,
      visibility = ["//visibility:private"],
  )

  go_library(
      name = name,
      srcs = cgogen.go_thunks + [
          cgogen.gotypes,
          cgogen.outdir + "/_cgo_import.go",
      ],
      cgo_object = cgogen.outdir + "/_cgo_object",
      go_tool = go_tool,
      toolchain = toolchain,
      **kwargs
  )

GO_TOOLCHAIN_BUILD_FILE = """
package(
  default_visibility = [ "//visibility:public" ])

filegroup(
  name = "toolchain",
  srcs = glob(["go/bin/*", "go/pkg/**", ]),
)

filegroup(
  name = "go_tool",
  srcs = [ "go/bin/go" ],
)
"""

def go_repositories():
  native.new_http_archive(
    name=  "golang_linux_amd64",
    url = "https://storage.googleapis.com/golang/go1.6.linux-amd64.tar.gz",
    build_file_content = GO_TOOLCHAIN_BUILD_FILE,
    sha256 = "5470eac05d273c74ff8bac7bef5bad0b5abbd1c4052efbdbc8db45332e836b0b"
  )

  native.new_http_archive(
    name=  "golang_darwin_amd64",
    url = "https://storage.googleapis.com/golang/go1.6.darwin-amd64.tar.gz",
    build_file_content = GO_TOOLCHAIN_BUILD_FILE,
    sha256 = "8b686ace24c0166738fd9f6003503f9d55ce03b7f24c963b043ba7bb56f43000"
  )
