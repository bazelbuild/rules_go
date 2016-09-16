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

go_filetype = FileType([".go", ".s", ".S"])
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
    pos = new_path.rfind('/')
    if pos >= 0:
      new_dir = new_path[:pos]
      up = (new_dir.count('/') + 1 +
            dest_dir.count('/') + 1)
    else:
      new_dir = ''
      up = dest_dir.count('/') + 1
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

def _emit_generate_params_action(cmds, ctx, fn):
  cmds_all = ["set -e"]
  cmds_all += cmds
  cmds_all_str = "\n".join(cmds_all)
  f = ctx.new_file(ctx.configuration.bin_dir, fn)
  ctx.file_action( output = f, content = cmds_all_str, executable = True)
  return f

def emit_go_asm_action(ctx, source, out_obj):
  """Construct the command line for compiling Go Assembly code.
  Constructs a symlink tree to accomodate for workspace name.
  Args:
    ctx: The skylark Context.
    source: a source code artifact
    out_obj: the artifact (configured target?) that should be produced
  """
  args = [
      ctx.file.go_tool.path, "tool", "asm",
      "-I", ctx.file.go_include.path,
      "-o", out_obj.path,
      source.path,
  ]
  cmds = [
      "export GOROOT=$(pwd)/" + ctx.file.go_tool.dirname + "/..",
      "mkdir -p " + out_obj.dirname,
      " ".join(args),
  ]

  f = _emit_generate_params_action(cmds, ctx, out_obj.path + ".GoAsmCompileFile.params")

  ctx.action(
      inputs = [source] + ctx.files.toolchain,
      outputs = [out_obj],
      mnemonic = "GoAsmCompile",
      executable = f,
  )

def _go_importpath(ctx):
  """Returns the expected importpath of the go_library being built.

  Args:
    ctx: The skylark Context

  Returns:
    Go importpath of the library
  """
  path = _go_prefix(ctx)[:-1]
  if ctx.label.package:
    path += "/" + ctx.label.package
  if ctx.label.name != _DEFAULT_LIB:
    path += "/" + ctx.label.name
  if path.rfind(_VENDOR_PREFIX) != -1:
    path = path[len(_VENDOR_PREFIX) + path.rfind(_VENDOR_PREFIX):]
  if path[0] == "/":
    path = path[1:]
  return path

def emit_go_compile_action(ctx, sources, deps, out_lib, extra_objects=[]):
  """Construct the command line for compiling Go code.
  Constructs a symlink tree to accommodate for workspace name.

  Args:
    ctx: The skylark Context.
    sources: an iterable of source code artifacts (or CTs? or labels?)
    deps: an iterable of dependencies. Each dependency d should have an
      artifact in d.go_library_object representing an imported library.
    out_lib: the artifact (configured target?) that should be produced
    extra_objects: an iterable of extra object files to be added to the
      output archive file.
  """
  tree_layout = {}
  inputs = []
  for d in deps:
    actual_path = d.go_library_object.path
    importpath = d.transitive_go_importmap[actual_path]
    tree_layout[actual_path] = importpath + ".a"
    inputs += [d.go_library_object]

  inputs += list(sources)
  prefix = _go_prefix(ctx)
  for s in sources:
    tree_layout[s.path] = prefix + s.path

  out_dir = out_lib.path + ".dir"
  out_depth = out_dir.count('/') + 1
  cmds = symlink_tree_commands(out_dir, tree_layout)
  args = [
      "cd ", out_dir, "&&",
      ('../' * out_depth) + ctx.file.go_tool.path,
      "tool", "compile",
      "-o", ('../' * out_depth) + out_lib.path, "-pack",
      "-I", "."
  ]

  # Set -p to the import path of the library, ie.
  # (ctx.label.package + "/" ctx.label.name) for now.
  cmds += [ "export GOROOT=$(pwd)/" + ctx.file.go_tool.dirname + "/..",
    ' '.join(args + cmd_helper.template(set(sources), prefix + "%{path}"))]
  extra_inputs = ctx.files.toolchain

  if extra_objects:
    extra_inputs += extra_objects
    objs = ' '.join([c.path for c in extra_objects])
    cmds += ["cd " + ('../' * out_depth),
             ctx.file.go_tool.path + " tool pack r " + out_lib.path + " " + objs]

  f = _emit_generate_params_action(cmds, ctx, out_lib.path + ".GoCompileFile.params")

  ctx.action(
      inputs = inputs + extra_inputs,
      outputs = [out_lib],
      mnemonic = "GoCompile",
      executable = f,
      env = go_environment_vars(ctx))

def go_library_impl(ctx):
  """Implements the go_library() rule."""

  sources = set(ctx.files.srcs)
  go_srcs = set([s for s in sources if s.basename.endswith('.go')])
  asm_srcs = [s for s in sources if s.basename.endswith('.s') or s.basename.endswith('.S')]
  deps = ctx.attr.deps

  cgo_object = None
  if hasattr(ctx.attr, "cgo_object"):
    cgo_object = ctx.attr.cgo_object

  if ctx.attr.library:
    go_srcs += ctx.attr.library.go_sources
    asm_srcs += ctx.attr.library.asm_sources
    deps += ctx.attr.library.direct_deps
    if ctx.attr.library.cgo_object:
      if cgo_object:
        fail("go_library %s cannot have cgo_object because the package " +
             "already has cgo_object in %s" % (ctx.label.name,
                                               ctx.attr.library.name))
      cgo_object = ctx.attr.library.cgo_object

  if not go_srcs:
    fail("may not be empty", "srcs")

  transitive_cgo_deps = set([], order="link")
  if cgo_object:
    transitive_cgo_deps += cgo_object.cgo_deps

  extra_objects = [cgo_object.cgo_obj] if cgo_object else []
  for src in asm_srcs:
    obj = ctx.new_file(src, "%s.dir/%s.o" % (ctx.label.name, src.basename[:-2]))
    emit_go_asm_action(ctx, src, obj)
    extra_objects += [obj]

  out_lib = ctx.outputs.lib
  emit_go_compile_action(ctx, go_srcs, deps, out_lib,
                         extra_objects=extra_objects)

  transitive_libs = set([out_lib])
  transitive_importmap = {out_lib.path: _go_importpath(ctx)}
  for dep in deps:
     transitive_libs += dep.transitive_go_library_object
     transitive_cgo_deps += dep.transitive_cgo_deps
     transitive_importmap += dep.transitive_go_importmap

  dylibs = []
  if cgo_object:
    dylibs += [d for d in cgo_object.cgo_deps if d.path.endswith(".so")]

  runfiles = ctx.runfiles(files = dylibs, collect_data = True)
  return struct(
    label = ctx.label,
    files = set([out_lib]),
    direct_deps = deps,
    runfiles = runfiles,
    go_sources = go_srcs,
    asm_sources = asm_srcs,
    go_library_object = out_lib,
    transitive_go_library_object = transitive_libs,
    cgo_object = cgo_object,
    transitive_cgo_deps = transitive_cgo_deps,
    transitive_go_importmap = transitive_importmap
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

def _short_path(f):
  """Returns a short path of the given file.

  It returns a relative path to the file from its root.
  This is a workaround of bazelbuild/bazel#1462
  """
  if not f.root.path:
    return f.path
  prefix = f.root.path
  if prefix[-1] != '/':
    prefix = prefix + '/'
  if not f.path.startswith(prefix):
    fail("file name %s is not prefixed with its root %s", f.path, prefix)
  return f.path[len(prefix):]

def emit_go_link_action(ctx, importmap, transitive_libs, cgo_deps, lib,
                        executable, x_defs={}):
  """Sets up a symlink tree to libraries to link together."""
  out_dir = executable.path + ".dir"
  out_depth = out_dir.count('/') + 1
  tree_layout = {}

  config_strip = len(ctx.configuration.bin_dir.path) + 1
  pkg_depth = executable.dirname[config_strip:].count('/') + 1
  prefix = _go_prefix(ctx)

  for l in transitive_libs:
    actual_path = l.path
    importpath = importmap[actual_path]
    tree_layout[l.path] = importpath + ".a"

  for d in cgo_deps:
    tree_layout[d.path] = _short_path(d)

  main_archive = importmap[lib.path] + ".a"
  tree_layout[lib.path] = main_archive

  ld = "%s" % ctx.fragments.cpp.compiler_executable
  if ld[0] != '/':
    ld = ('../' * out_depth) + ld
  ldflags = _c_linker_options(ctx) + [
      "-Wl,-rpath,$ORIGIN/" + ("../" * pkg_depth),
      "-L" + prefix,
  ]
  for d in cgo_deps:
    if d.basename.endswith('.so'):
      dirname = _short_path(d)[:-len(d.basename)]
      ldflags += ["-Wl,-rpath,$ORIGIN/" + ("../" * pkg_depth) + dirname]

  link_cmd = [
      ('../' * out_depth) + ctx.file.go_tool.path,
      "tool", "link", "-L", ".",
      "-o", _go_importpath(ctx),
  ]

  if x_defs:
    link_cmd += [" -X %s='%s' " % (k, v) for k,v in x_defs.items()]

  # workaround for a bug in ld(1) on Mac OS X.
  # http://lists.apple.com/archives/Darwin-dev/2006/Sep/msg00084.html
  # TODO(yugui) Remove this workaround once rules_go stops supporting XCode 7.2
  # or earlier.
  if ctx.fragments.cpp.cpu != 'darwin':
    link_cmd += ["-s"]

  link_cmd += [
      "-extld", ld,
      "-extldflags", "'%s'" % " ".join(ldflags),
      main_archive,
  ]

  cmds = symlink_tree_commands(out_dir, tree_layout)
  # Avoided -s on OSX but but it requires dsymutil to be on $PATH.
  # TODO(yugui) Remove this workaround once rules_go stops supporting XCode 7.2
  # or earlier.
  cmds += ["export PATH=$PATH:/usr/bin"]
  cmds += [
    "export GOROOT=$(pwd)/" + ctx.file.go_tool.dirname + "/..",
    "cd " + out_dir,
    ' '.join(link_cmd),
    "mv -f " + _go_importpath(ctx) + " " + ("../" * out_depth) + executable.path,
  ]

  f = _emit_generate_params_action(cmds, ctx, lib.path + ".GoLinkFile.params")

  ctx.action(
      inputs = (list(transitive_libs) + [lib] + list(cgo_deps) +
                ctx.files.toolchain + ctx.files._crosstool),
      outputs = [executable],
      executable = f,
      mnemonic = "GoLink",
      env = go_environment_vars(ctx))

def go_binary_impl(ctx):
  """go_binary_impl emits actions for compiling and linking a go executable."""
  lib_result = go_library_impl(ctx)
  executable = ctx.outputs.executable
  lib_out = ctx.outputs.lib

  emit_go_link_action(
    ctx,
    transitive_libs=lib_result.transitive_go_library_object,
    importmap=lib_result.transitive_go_importmap,
    cgo_deps=lib_result.transitive_cgo_deps,
    lib=lib_out, executable=executable,
    x_defs=ctx.attr.x_defs)

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

  go_import = _go_importpath(ctx)

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

  importmap = lib_result.transitive_go_importmap + {
      ctx.outputs.main_lib.path: _go_importpath(ctx) + "_main_test"}
  emit_go_link_action(
    ctx,
    importmap=importmap,
    transitive_libs=lib_result.transitive_go_library_object,
    cgo_deps=lib_result.transitive_cgo_deps,
    lib=ctx.outputs.main_lib, executable=ctx.outputs.executable,
    x_defs=ctx.attr.x_defs)

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
        cfg = "host",
    ),
    "go_tool": attr.label(
        default = Label("//go/toolchain:go_tool"),
        single_file = True,
        allow_files = True,
        cfg = "host",
    ),
    "go_prefix": attr.label(
        providers = ["go_prefix"],
        default = Label(
            "//:go_prefix",
            relative_to_caller_repository = True,
        ),
        allow_files = False,
        cfg = "host",
    ),
    "go_include": attr.label(
        default = Label("//go/toolchain:go_include"),
        single_file = True,
        allow_files = True,
        cfg = "host",
    ),
}

go_library_attrs = go_env_attrs + {
    "data": attr.label_list(
        allow_files = True,
        cfg = "data",
    ),
    "srcs": attr.label_list(allow_files = go_filetype),
    "deps": attr.label_list(
        providers = [
            "direct_deps",
            "go_library_object",
            "transitive_go_importmap",
            "transitive_go_library_object",
            "transitive_cgo_deps",
        ],
    ),
    "library": attr.label(
        providers = ["go_sources", "asm_sources", "cgo_object"],
    ),
}

_crosstool_attrs = {
    "_crosstool": attr.label(
        default = Label("//tools/defaults:crosstool"),
    )
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
    attrs = go_library_attrs + _crosstool_attrs + {
        "stamp": attr.bool(default = False),
        "x_defs": attr.string_dict(),
    },
    executable = True,
    fragments = ["cpp"],
    outputs = go_library_outputs,
)

go_test = rule(
    go_test_impl,
    attrs = go_library_attrs + _crosstool_attrs + {
        "test_generator": attr.label(
            executable = True,
            default = Label(
                "//go/tools:generate_test_main",
            ),
            cfg = "host",
        ),
        "x_defs": attr.string_dict(),
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


def _pkg_dir(workspace_root, package_name):
  if workspace_root and package_name:
    return workspace_root + "/" + package_name
  if workspace_root:
    return workspace_root
  if package_name:
    return package_name
  return "."

def _exec_path(path):
  if path.startswith('/'):
    return path
  return '${execroot}/' + path

def _cgo_codegen_impl(ctx):
  srcs = ctx.files.srcs + ctx.files.c_hdrs
  linkopts = ctx.attr.linkopts
  copts = ctx.fragments.cpp.c_options + ctx.attr.copts
  deps = set([], order="link")
  for d in ctx.attr.deps:
    srcs += list(d.cc.transitive_headers)
    deps += d.cc.libs
    copts += ['-D' + define for define in d.cc.defines]
    for inc in d.cc.include_directories:
      copts += ['-I', _exec_path(inc)]
    for inc in d.cc.quote_include_directories:
      copts += ['-iquote', _exec_path(inc)]
    for inc in d.cc.system_include_directories:
      copts += ['-isystem',  _exec_path(inc)]
    for lib in d.cc.libs:
      if lib.basename.startswith('lib') and lib.basename.endswith('.so'):
        dirname = _short_path(lib)[:-len(lib.basename)]
        linkopts += ['-L', dirname, '-l', lib.basename[3:-3]]
      else:
        linkopts += [_short_path(lib)]
    linkopts += d.cc.link_flags

  # collect files from $(SRCDIR), $(GENDIR) and $(BINDIR)
  tree_layout = {}
  for s in srcs:
    tree_layout[s.path] = _short_path(s)

  out_dir = (ctx.configuration.genfiles_dir.path + '/' +
             _pkg_dir(ctx.label.workspace_root, ctx.label.package) + "/" +
             ctx.attr.outdir)
  cc = ctx.fragments.cpp.compiler_executable
  cmds = symlink_tree_commands(out_dir + "/src", tree_layout) + [
      "export GOROOT=$(pwd)/" + ctx.file.go_tool.dirname + "/..",
      # We cannot use env for CC because $(CC) on OSX is relative
      # and '../' does not work fine due to symlinks.
      "export CC=$(cd $(dirname {cc}); pwd)/$(basename {cc})".format(cc=cc),
      "export CXX=$CC",
      "execroot=$(pwd)",
      "objdir=$(pwd)/%s/gen" % out_dir,
      "mkdir -p $objdir",
      # The working directory must be the directory of the target go package
      # to prevent cgo from prefixing mangled directory names to the output
      # files.
      "cd %s/src/$(dirname %s)" % (out_dir, _short_path(ctx.files.srcs[0])),
      ' '.join(["$GOROOT/bin/go", "tool", "cgo", "-objdir", "$objdir", "--"] +
               copts + [f.basename for f in ctx.files.srcs]),
      "rm -f $objdir/_cgo_.o $objdir/_cgo_flags"]

  f = _emit_generate_params_action(cmds, ctx, out_dir + ".CGoCodeGenFile.params")

  ctx.action(
      inputs = srcs + ctx.files.toolchain + ctx.files._crosstool,
      outputs = ctx.outputs.outs,
      mnemonic = "CGoCodeGen",
      progress_message = "CGoCodeGen %s" % ctx.label,
      executable = f,
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
    attrs = go_env_attrs + _crosstool_attrs + {
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
  outgen = outdir + "/gen"

  go_thunks = []
  c_thunks = []
  for s in srcs:
    if not s.endswith('.go'):
      fail("not a .go file: %s" % s)
    basename = s[:-3]
    if basename.rfind("/") >= 0:
      basename = basename[basename.rfind("/")+1:]
    go_thunks.append(outgen + "/" + basename + ".cgo1.go")
    c_thunks.append(outgen + "/" + basename + ".cgo2.c")

  outs = struct(
      name = name,

      outdir = outgen,
      go_thunks = go_thunks,
      c_thunks = c_thunks,
      c_exports = [
          outgen + "/_cgo_export.c",
          outgen + "/_cgo_export.h",
      ],
      c_dummy = outgen + "/_cgo_main.c",
      gotypes = outgen + "/_cgo_gotypes.go",
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
  f = _emit_generate_params_action(cmds, ctx, ctx.outputs.out.path + ".CGoImportGenFile.params")
  ctx.action(
      inputs = (ctx.files.toolchain +
                [ctx.file.go_tool, ctx.executable._extract_package,
                 ctx.file.cgo_o, ctx.file.sample_go_src]),
      outputs = [ctx.outputs.out],
      executable = f,
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
            cfg = "host",
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
      inputs = [lo] + ctx.files._crosstool,
      outputs = [ctx.outputs.out],
      mnemonic = "CGoObject",
      progress_message = "Linking %s" % _short_path(ctx.outputs.out),
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
    attrs = _crosstool_attrs + {
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
                clinkopts=[],
                cdeps=[],
                **kwargs):
  """Builds a cgo-enabled go library.

  Args:
    name: A unique name for this rule.
    srcs: List of Go, C and C++ files that are processed to build a Go library.
      Those Go files must contain `import "C"`.
      C and C++ files can be anything allowed in `srcs` attribute of
      `cc_library`.
    copts: Add these flags to the C++ compiler.
    clinkopts: Add these flags to the C++ linker.
    cdeps: List of C/C++ libraries to be linked into the binary target.
      They must be `cc_library` rules.
    deps: List of other libraries to be linked to this library target.
    data: List of files needed by this rule at runtime.

  NOTE:
    `srcs` cannot contain pure-Go files, which do not have `import "C"`.
    So you need to define another `go_library` when you build a go package with
    both cgo-enabled and pure-Go sources.

    ```
    cgo_library(
        name = "cgo_enabled",
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
      deps = cdeps,
      linkopts = clinkopts,
      go_tool = go_tool,
      toolchain = toolchain,
  )

  pkg_dir = _pkg_dir(
      "external/" + REPOSITORY_NAME[1:] if len(REPOSITORY_NAME) > 1 else "",
      PACKAGE_NAME)
  # Bundles objects into an archive so that _cgo_.o and _all.o can share them.
  native.cc_library(
      name = cgogen.outdir + "/_cgo_lib",
      srcs = cgogen.c_thunks + cgogen.c_exports + c_srcs + c_hdrs,
      deps = cdeps,
      copts = copts + [
          "-I", pkg_dir,
          "-I", "$(GENDIR)/" + pkg_dir + "/" + cgogen.outdir,
          # The generated thunks often contain unused variables.
          "-Wno-unused-variable",
      ],
      linkopts = clinkopts,
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
      deps = cdeps + [cgogen.outdir + "/_cgo_lib"],
      copts = copts,
      linkopts = clinkopts,
      visibility = ["//visibility:private"],
  )
  _cgo_import(
      name = "%s.cgo.importgen" % name,
      cgo_o = cgogen.outdir + "/_cgo_.o",
      out = cgogen.outdir + "/_cgo_import.go",
      sample_go_src = go_srcs[0],
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

################

def _go_repository_impl(ctx):
  fetch_repo = ctx.path(ctx.attr._fetch_repo)

  if ctx.attr.commit and ctx.attr.tag:
    fail("cannot specify both of commit and tag", "commit")
  if ctx.attr.commit:
    rev = ctx.attr.commit
  elif ctx.attr.tag:
    rev = ctx.attr.tag
  else:
    fail("neither commit or tag is specified", "commit")

  # TODO(yugui): support submodule?
  # c.f. https://www.bazel.io/versions/master/docs/be/workspace.html#git_repository.init_submodules
  result = ctx.execute([
      fetch_repo,
      '--dest', ctx.path(''),
      '--remote', ctx.attr.importpath,
      '--rev', rev])
  if result.return_code:
    fail("failed to fetch %s: %s" % (ctx.attr.importpath, result.stderr))

def _new_go_repository_impl(ctx):
  _go_repository_impl(ctx)
  gazelle = ctx.path(ctx.attr._gazelle)

  result = ctx.execute([
      gazelle,
      '--go_prefix', ctx.attr.importpath, '--mode', 'fix',
      ctx.path('')])
  if result.return_code:
    fail("failed to generate BUILD files for %s: %s" % (
        ctx.attr.importpath, result.stderr))

_go_repository_attrs = {
    "importpath": attr.string(mandatory = True),
    "commit": attr.string(),
    "tag": attr.string(),

    "_fetch_repo": attr.label(
        default = Label("@io_bazel_rules_go_repository_tools//:bin/fetch_repo"),
        allow_files = True,
        single_file = True,
        executable = True,
        cfg = "host",
    ),
}

go_repository = repository_rule(
    implementation = _go_repository_impl,
    attrs = _go_repository_attrs,
)

new_go_repository = repository_rule(
    implementation = _new_go_repository_impl,
    attrs = _go_repository_attrs + {
        "_gazelle": attr.label(
            default = Label("@io_bazel_rules_go_repository_tools//:bin/gazelle"),
            allow_files = True,
            single_file = True,
            executable = True,
            cfg = "host",
        ),
    },
)

################

repository_tool_deps = {
    'buildifier': struct(
        importpath = 'github.com/bazelbuild/buildifier',
        repo = 'https://github.com/bazelbuild/buildifier',
        commit = '0ca1d7991357ae7a7555589af88930d82cf07c0a',
    ),
    'tools': struct(
        importpath = 'golang.org/x/tools',
        repo = 'https://github.com/golang/tools',
        commit = '2bbdb4568e161d12394da43e88b384c6be63928b',
    )
}

def go_internal_tools_deps():
  """only for internal use in rules_go"""
  go_repository(
      name = "io_bazel_buildifier",
      commit = repository_tool_deps['buildifier'].commit,
      importpath = repository_tool_deps['buildifier'].importpath,
  )

  new_go_repository(
      name = "org_golang_x_tools",
      commit = repository_tool_deps['tools'].commit,
      importpath = repository_tool_deps['tools'].importpath,
  )

def _fetch_repository_tools_deps(ctx, goroot, gopath):
  for name, dep in repository_tool_deps.items():
    result = ctx.execute(['mkdir', '-p', ctx.path('src/' + dep.importpath)])
    if result.return_code:
      fail('failed to create directory: %s' % result.stderr)
    ctx.download_and_extract(
        '%s/archive/%s.zip' % (dep.repo, dep.commit),
        'src/%s' % dep.importpath, '', 'zip', '%s-%s' % (name, dep.commit))

  result = ctx.execute([
      'env', 'GOROOT=%s' % goroot, 'GOPATH=%s' % gopath, 'PATH=%s/bin' % goroot,
      'go', 'generate', 'github.com/bazelbuild/buildifier/core'])
  if result.return_code:
    fail("failed to go genrate: %s" % result.stderr)

_GO_REPOSITORY_TOOLS_BUILD_FILE = """
package(default_visibility = ["//visibility:public"])

filegroup(
    name = "fetch_repo",
    srcs = ["bin/fetch_repo"],
)

filegroup(
    name = "gazelle",
    srcs = ["bin/gazelle"],
)
"""

def _go_repository_tools_impl(ctx):
  go_tool = ctx.path(ctx.attr._go_tool)
  goroot = go_tool.dirname.dirname
  gopath = ctx.path('')
  prefix = "github.com/bazelbuild/rules_go/" + ctx.attr._tools.package
  src_path = ctx.path(ctx.attr._tools).dirname

  _fetch_repository_tools_deps(ctx, goroot, gopath)

  for t, pkg in [("gazelle", 'gazelle/gazelle'), ("fetch_repo", "fetch_repo")]:
    ctx.symlink("%s/%s" % (src_path, t), "src/%s/%s" % (prefix, t))

    result = ctx.execute([
        'env', 'GOROOT=%s' % goroot, 'GOPATH=%s' % gopath,
        go_tool, "build",
        "-o", ctx.path("bin/" + t), "%s/%s" % (prefix, pkg)])
    if result.return_code:
      fail("failed to build %s: %s" % (t, result.stderr))
  ctx.file('BUILD', _GO_REPOSITORY_TOOLS_BUILD_FILE, False)

_go_repository_tools = repository_rule(
    _go_repository_tools_impl,
    attrs = {
        "_tools": attr.label(
            default = Label("//go/tools:BUILD"),
            allow_files = True,
            single_file = True,
        ),
        "_go_tool": attr.label(
            default = Label("@io_bazel_rules_go_toolchain//:bin/go"),
            allow_files = True,
            single_file = True,
        ),
        "_x_tools": attr.label(
            default = Label("@org_golang_x_tools//:BUILD"),
            allow_files = True,
            single_file = True,
        ),
        "_buildifier": attr.label(
            default = Label("@io_bazel_buildifier//:BUILD"),
            allow_files = True,
            single_file = True,
        ),
    },
)

GO_TOOLCHAIN_BUILD_FILE = """
package(
  default_visibility = [ "//visibility:public" ])

filegroup(
  name = "toolchain",
  srcs = glob(["bin/*", "pkg/**", ]),
)

filegroup(
  name = "go_tool",
  srcs = [ "bin/go" ],
)

filegroup(
  name = "go_include",
  srcs = [ "pkg/include" ],
)
"""

def _go_repository_select_impl(ctx):
  os = ctx.os.name
  # NOTE: This mapping cannot be table-driven to prevent
  # Bazel from downloading the other archive.
  if os == 'linux':
    goroot = ctx.path(ctx.attr._linux).dirname
  elif os == 'mac os x':
    goroot = ctx.path(ctx.attr._darwin).dirname
  else:
    fail("unsupported operating system: " + os)

  ctx.symlink(goroot, ctx.path(''))

_go_repository_select = repository_rule(
    _go_repository_select_impl,
    attrs = {
        "_linux": attr.label(
            default = Label("@golang_linux_amd64//:BUILD"),
            allow_files = True,
            single_file = True,
        ),
        "_darwin": attr.label(
            default = Label("@golang_darwin_amd64//:BUILD"),
            allow_files = True,
            single_file = True,
        ),
    },
)

def go_repositories():
  native.new_http_archive(
      name =  "golang_linux_amd64",
      url = "https://storage.googleapis.com/golang/go1.7.1.linux-amd64.tar.gz",
      build_file_content = GO_TOOLCHAIN_BUILD_FILE,
      sha256 = "43ad621c9b014cde8db17393dc108378d37bc853aa351a6c74bf6432c1bbd182",
      strip_prefix = "go",
  )

  native.new_http_archive(
      name = "golang_darwin_amd64",
      url = "https://storage.googleapis.com/golang/go1.7.1.darwin-amd64.tar.gz",
      build_file_content = GO_TOOLCHAIN_BUILD_FILE,
      sha256 = "9fd80f19cc0097f35eaa3a52ee28795c5371bb6fac69d2acf70c22c02791f912",
      strip_prefix = "go",
  )

  _go_repository_select(
      name = "io_bazel_rules_go_toolchain",
  )
  _go_repository_tools(
      name = "io_bazel_rules_go_repository_tools",
  )
