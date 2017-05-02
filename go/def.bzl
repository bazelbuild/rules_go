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

load("//go/private:go_repositories.bzl", "go_repositories")
load("//go/private:go_repository.bzl", "go_repository", "new_go_repository")
load("//go/private:go_prefix.bzl", "go_prefix")
load("//go/private:json.bzl", "json_marshal")

"""These are bare-bones Go rules.

In order of priority:

- BUILD file must be written by hand.

- No support for SWIG

- No test sharding or test XML.

"""

_DEFAULT_LIB = "go_default_library"

_VENDOR_PREFIX = "/vendor/"

go_filetype = FileType([
    ".go",
    ".s",
    ".S",
    ".h",  # may be included by .s
])

# be consistent to cc_library.
hdr_exts = [
    ".h",
    ".hh",
    ".hpp",
    ".hxx",
    ".inc",
]

cc_hdr_filetype = FileType(hdr_exts)

# Extensions of files we can build with the Go compiler or with cc_library.
# This is a subset of the extensions recognized by go/build.
cgo_filetype = FileType([
    ".go",
    ".c",
    ".cc",
    ".cxx",
    ".cpp",
    ".s",
    ".S",
    ".h",
    ".hh",
    ".hpp",
    ".hxx",
])

################

def _go_prefix(ctx):
  """slash terminated go-prefix"""
  prefix = ctx.attr.go_prefix.go_prefix
  if prefix != "" and not prefix.endswith("/"):
    prefix = prefix + "/"
  return prefix

def _relative_path_from_dir(from_dir, to_file):
  """Returns a relative path from from_dir to to_file.

  Useful for constructing paths from working directories, mostly for symlinks.
  Both paths must be relative to the execroot.
  """
  if _is_external(from_dir):
    from_dir = _remove_external_prefix(from_dir)
  if from_dir == "" or from_dir == ".":
    up = 0
  else:
    up = from_dir.count('/') + 1
  return up * "../" + to_file

def _build_file_tree(ctx, dest_dir, artifact_dict):
  """_build_file_tree creates the specified file structure.

  Args:
    dest_dir: The destination directory, a string.
              Because all files are added with ctx.new_file, this should
              be relative to the current package, not the working directory.
    artifact_dict: The mapping of exec-path => path in the dest_dir.
                   All keys must be files.
  Returns: The set of files created.
  """
  linked = []
  for src, new_path in artifact_dict.items():
    new_file = ctx.new_file(dest_dir + "/" + new_path)
    linked += [new_file]
    ctx.action(
        inputs=[src],
        outputs=[new_file],
        command=["cp", src.path, new_file.path],
    )
  return linked


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

    if _is_external(dest_dir):
      """In old versions of Bazel, external execroot paths were of the form
      bazel-out/host/bin/external/repo/path/to/target, so counting up the /s
      worked fine. In bazel 5.0+, execution roots began to look like
      ../repo/bazel-out/host/bin/path/to/target.  The ../repo basically ends
      up resolving to 0 path elements, so 2 segments should be removed from the
      count."""
      up -= 2
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
                           "darwin_x86_64": {"GOOS": "darwin",
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

def _is_darwin_cpu(ctx):
  cpu = ctx.fragments.cpp.cpu
  return cpu == "darwin" or cpu == "darwin_x86_64"

def _emit_generate_params_action(cmds, ctx, fn):
  cmds_all = [
      # Use bash explicitly. /bin/sh is default, and it may be linked to a
      # different shell, e.g., /bin/dash on Ubuntu.
      "#!/bin/bash",
      "set -e",
  ]
  cmds_all += cmds
  cmds_all_str = "\n".join(cmds_all) + "\n"
  f = ctx.new_file(ctx.configuration.bin_dir, fn)
  ctx.file_action(
      output = f,
      content = cmds_all_str,
      executable = True)
  return f

def _emit_go_asm_action(ctx, source, hdrs, out_obj):
  """Construct the command line for compiling Go Assembly code.
  Constructs a symlink tree to accomodate for workspace name.
  Args:
    ctx: The skylark Context.
    source: a source code artifact
    hdrs: list of .h files that may be included
    out_obj: the artifact (configured target?) that should be produced
  """
  params = {
      "go_tool": ctx.file.go_tool.path,
      "includes": [f.dirname for f in hdrs] + [ctx.file.go_include.path],
      "source": source.path,
      "out": out_obj.path,
  }

  inputs = hdrs + ctx.files.toolchain + [source]
  ctx.action(
      inputs = inputs,
      outputs = [out_obj],
      mnemonic = "GoAsmCompile",
      executable = ctx.executable._asm,
      arguments = [json_marshal(params)],
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

def _remove_external_prefix(old_path):
  """Removes the ../repo_name prefix from paths.
  These prefixes aren't used in the go symlink tree."""
  if _is_external(old_path):
    old_path = old_path[old_path.find('/', 3) + 1:]
  return old_path

def _is_external(p):
  """Checks if the string starts with ../"""
  return p[0:3] == '../'

def _emit_go_compile_action(ctx, sources, deps, out_lib,
                            extra_objects, gc_goopts):
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
    gc_goopts: additional flags to pass to the compiler.
  """
  # Build a symlink tree so that that deps are in directories that match
  # their import paths.
  tree_layout = {}
  inputs = []
  for d in deps:
    importpath = d.transitive_go_importmap[d.go_library_object.path]
    tree_layout[d.go_library_object] = importpath + ".a"

  inputs += list(sources)
  prefix = _go_prefix(ctx)

  inputs += _build_file_tree(ctx, out_lib.basename + ".dir", tree_layout)

  cmds = [
      'export GOROOT=$(pwd)/%s/..' % ctx.file.go_tool.dirname,
  ]

  # Filter source files using build tags.
  cleaned_go_source_paths = [
      i.path
      for i in sources
      if not i.basename.startswith("_cgo")]
  cleaned_cgo_source_paths = [
      i.path
      for i in sources
      if i.basename.startswith("_cgo")]
  cmds += [
      'UNFILTERED_GO_FILES=(%s)' % 
          ' '.join(["'%s'" % f for f in cleaned_go_source_paths]),
      'FILTERED_GO_FILES=(%s)' %
          ' '.join(["'%s'" % f for f in cleaned_cgo_source_paths]),
      'while read -r line; do',
      '  if [ -n "$line" ]; then',
      '    FILTERED_GO_FILES+=("$line")',
      '  fi',
      'done < <(\'%s\' -cgo "${UNFILTERED_GO_FILES[@]}")' % ctx.executable._filter_tags.path,
      'if [ ${#FILTERED_GO_FILES[@]} -eq 0 ]; then',
      '  echo no buildable Go source files in %s >&1' % str(ctx.label),
      '  exit 1',
      'fi',
  ]

  # Compile filtered files.
  args = [
      ctx.file.go_tool.path,
      "tool", "compile",
      "-o", out_lib.path, "-pack",
      "-I", ".",
      "-I", out_lib.path + ".dir",
      "-trimpath", "$(pwd)",
  ] + gc_goopts + ['"${FILTERED_GO_FILES[@]}"']

  # Pack extra objects into an archive, if provided.
  # Set -p to the import path of the library, ie.
  # (ctx.label.package + "/" ctx.label.name) for now.
  cmds += [' '.join(args)]

  extra_inputs = ctx.files.toolchain
  if extra_objects:
    extra_inputs += extra_objects
    objs = ' '.join([c.path for c in extra_objects])
    cmds += [ctx.file.go_tool.path + " tool pack r " + out_lib.path + " " + objs]

  f = _emit_generate_params_action(cmds, ctx, out_lib.basename + ".GoCompileFile.params")

  ctx.action(
      inputs = [f] + inputs + extra_inputs + [ctx.executable._filter_tags],
      outputs = [out_lib],
      mnemonic = "GoCompile",
      command = f.path,
      env = go_environment_vars(ctx))

def go_library_impl(ctx):
  """Implements the go_library() rule."""

  sources = set(ctx.files.srcs)
  go_srcs = set([s for s in sources if s.basename.endswith('.go')])
  asm_srcs = [s for s in sources if s.basename.endswith('.s') or s.basename.endswith('.S')]
  asm_hdrs = [s for s in sources if s.basename.endswith('.h')]
  deps = ctx.attr.deps
  dep_runfiles = [d.data_runfiles for d in deps]

  cgo_object = None
  if hasattr(ctx.attr, "cgo_object"):
    cgo_object = ctx.attr.cgo_object

  if ctx.attr.library:
    go_srcs += ctx.attr.library.go_sources
    asm_srcs += ctx.attr.library.asm_sources
    asm_hdrs += ctx.attr.library.asm_headers
    deps += ctx.attr.library.direct_deps
    dep_runfiles += [ctx.attr.library.data_runfiles]
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
    dep_runfiles += [cgo_object.data_runfiles]
    transitive_cgo_deps += cgo_object.cgo_deps

  extra_objects = [cgo_object.cgo_obj] if cgo_object else []
  for src in asm_srcs:
    obj = ctx.new_file(src, "%s.dir/%s.o" % (ctx.label.name, src.basename[:-2]))
    _emit_go_asm_action(ctx, src, asm_hdrs, obj)
    extra_objects += [obj]

  out_lib = ctx.outputs.lib
  gc_goopts = _gc_goopts(ctx)
  _emit_go_compile_action(ctx, go_srcs, deps, out_lib, extra_objects, gc_goopts)

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
  for d in dep_runfiles:
    runfiles = runfiles.merge(d)

  return struct(
    label = ctx.label,
    files = set([out_lib]),
    direct_deps = deps,
    runfiles = runfiles,
    go_sources = go_srcs,
    asm_sources = asm_srcs,
    asm_headers = asm_hdrs,
    go_library_object = out_lib,
    transitive_go_library_object = transitive_libs,
    cgo_object = cgo_object,
    transitive_cgo_deps = transitive_cgo_deps,
    transitive_go_importmap = transitive_importmap,
    gc_goopts = gc_goopts,
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

def _gc_goopts(ctx):
  gc_goopts = [ctx.expand_make_variables("gc_goopts", f, {})
               for f in ctx.attr.gc_goopts]
  if ctx.attr.library:
    gc_goopts += ctx.attr.library.gc_goopts
  return gc_goopts

def _gc_linkopts(ctx):
  gc_linkopts = [ctx.expand_make_variables("gc_linkopts", f, {})
                 for f in ctx.attr.gc_linkopts]
  for k, v in ctx.attr.x_defs.items():
    gc_linkopts += ["-X", "%s='%s'" % (k, v)]
  return gc_linkopts

def _extract_extldflags(gc_linkopts, extldflags):
  """Extracts -extldflags from gc_linkopts and combines them into a single list.

  Args:
    gc_linkopts: a list of flags passed in through the gc_linkopts attributes.
      ctx.expand_make_variables should have already been applied.
    extldflags: a list of flags to be passed to the external linker.

  Return:
    A tuple containing the filtered gc_linkopts with external flags removed,
    and a combined list of external flags.
  """
  filtered_gc_linkopts = []
  is_extldflags = False
  for opt in gc_linkopts:
    if is_extldflags:
      is_extldflags = False
      extldflags += [opt]
    elif opt == "-extldflags":
      is_extldflags = True
    else:
      filtered_gc_linkopts += [opt]
  return filtered_gc_linkopts, extldflags

def _emit_go_link_action(ctx, importmap, transitive_libs, cgo_deps, lib,
                         executable, gc_linkopts):
  """Sets up a symlink tree to libraries to link together."""
  out_dir = executable.path + ".dir"
  out_depth = out_dir.count('/') + 1
  if _is_external(out_dir):
    out_depth -= 2
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
  extldflags = _c_linker_options(ctx) + [
      "-Wl,-rpath,$ORIGIN/" + ("../" * pkg_depth),
  ]
  if prefix:
    extldflags.append("-L" + prefix)
  for d in cgo_deps:
    if d.basename.endswith('.so'):
      dirname = _short_path(d)[:-len(d.basename)]
      extldflags += ["-Wl,-rpath,$ORIGIN/" + ("../" * pkg_depth) + dirname]
  gc_linkopts, extldflags = _extract_extldflags(gc_linkopts, extldflags)

  link_cmd = [
      ('../' * out_depth) + ctx.file.go_tool.path,
      "tool", "link", "-L", ".",
      "-o", _go_importpath(ctx),
  ] + gc_linkopts + ['"${STAMP_XDEFS[@]}"']

  # workaround for a bug in ld(1) on Mac OS X.
  # http://lists.apple.com/archives/Darwin-dev/2006/Sep/msg00084.html
  # TODO(yugui) Remove this workaround once rules_go stops supporting XCode 7.2
  # or earlier.
  if not _is_darwin_cpu(ctx):
    link_cmd += ["-s"]

  link_cmd += [
      "-extld", ld,
      "-extldflags", "'%s'" % " ".join(extldflags),
      main_archive,
  ]

  cmds = symlink_tree_commands(out_dir, tree_layout)
  # Avoided -s on OSX but but it requires dsymutil to be on $PATH.
  # TODO(yugui) Remove this workaround once rules_go stops supporting XCode 7.2
  # or earlier.
  cmds += ["export PATH=$PATH:/usr/bin"]

  cmds += [
      "export GOROOT=$(pwd)/" + ctx.file.go_tool.dirname + "/..",
      "STAMP_XDEFS=()",
  ]

  stamp_inputs = []
  if ctx.attr.linkstamp:
    # read workspace status files, converting "KEY value" lines
    # to "-X $linkstamp.KEY=value" arguments to the go linker.
    stamp_inputs = [ctx.info_file, ctx.version_file]
    for f in stamp_inputs:
      cmds += [
          "while read -r key value || [[ -n $key ]]; do",
          "  STAMP_XDEFS+=(-X \"%s.$key=$value\")" % ctx.attr.linkstamp,
          "done < " + f.path,
      ]

  cmds += [
    "cd " + out_dir,
    ' '.join(link_cmd),
    "mv -f " + _go_importpath(ctx) + " " + ("../" * out_depth) + executable.path,
  ]

  f = _emit_generate_params_action(cmds, ctx, lib.basename + ".GoLinkFile.params")

  ctx.action(
      inputs = [f] + (list(transitive_libs) + [lib] + list(cgo_deps) +
                ctx.files.toolchain + ctx.files._crosstool) + stamp_inputs,
      outputs = [executable],
      command = f.path,
      mnemonic = "GoLink",
      env = go_environment_vars(ctx))

def go_binary_impl(ctx):
  """go_binary_impl emits actions for compiling and linking a go executable."""
  lib_result = go_library_impl(ctx)
  executable = ctx.outputs.executable
  lib_out = ctx.outputs.lib

  _emit_go_link_action(
    ctx,
    transitive_libs=lib_result.transitive_go_library_object,
    importmap=lib_result.transitive_go_importmap,
    cgo_deps=lib_result.transitive_cgo_deps,
    lib=lib_out, executable=executable,
    gc_linkopts=_gc_linkopts(ctx))

  return struct(files = set([executable]),
                runfiles = lib_result.runfiles,
                cgo_object = lib_result.cgo_object)

def go_test_impl(ctx):
  """go_test_impl implements go testing.

  It emits an action to run the test generator, and then compiles the
  test into a binary."""

  lib_result = go_library_impl(ctx)
  main_go = ctx.outputs.main_go
  prefix = _go_prefix(ctx)
  go_import = _go_importpath(ctx)

  cmds = [
      'UNFILTERED_TEST_FILES=(%s)' %
          ' '.join(["'%s'" % f.path for f in lib_result.go_sources]),
      'FILTERED_TEST_FILES=()',
      'while read -r line; do',
      '  if [ -n "$line" ]; then',
      '    FILTERED_TEST_FILES+=("$line")',
      '  fi',
      'done < <(\'%s\' -cgo "${UNFILTERED_TEST_FILES[@]}")' %
          ctx.executable._filter_tags.path,
      ' '.join([
          "'%s'" % ctx.executable.test_generator.path,
          '--package',
          go_import,
          '--output',
          "'%s'" % ctx.outputs.main_go.path,
          '"${FILTERED_TEST_FILES[@]}"',
      ]),
  ]
  f = _emit_generate_params_action(
      cmds, ctx, main_go.path + ".GoTestGenTest.params")
  inputs = (list(lib_result.go_sources) + list(ctx.files.toolchain) +
            [f, ctx.executable._filter_tags, ctx.executable.test_generator])
  ctx.action(
      inputs = inputs,
      outputs = [main_go],
      command = f.path,
      mnemonic = "GoTestGenTest",
      env = dict(go_environment_vars(ctx), RUNDIR=ctx.label.package))

  _emit_go_compile_action(
    ctx,
    sources=set([main_go]),
    deps=ctx.attr.deps + [lib_result],
    out_lib=ctx.outputs.main_lib,
    extra_objects=[],
    gc_goopts=_gc_goopts(ctx))

  importmap = lib_result.transitive_go_importmap + {
      ctx.outputs.main_lib.path: _go_importpath(ctx) + "_main_test"}
  _emit_go_link_action(
    ctx,
    importmap=importmap,
    transitive_libs=lib_result.transitive_go_library_object,
    cgo_deps=lib_result.transitive_cgo_deps,
    lib=ctx.outputs.main_lib, executable=ctx.outputs.executable,
    gc_linkopts=_gc_linkopts(ctx))

  # TODO(bazel-team): the Go tests should do a chdir to the directory
  # holding the data files, so open-source go tests continue to work
  # without code changes.
  runfiles = ctx.runfiles(files = [ctx.outputs.executable])
  runfiles = runfiles.merge(lib_result.runfiles)
  return struct(
      files = set([ctx.outputs.executable]),
      runfiles = runfiles,
  )

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
    "go_src": attr.label(
        default = Label("//go/toolchain:go_src"),
        allow_files = True,
        cfg = "host",
    ),
    "go_include": attr.label(
        default = Label("//go/toolchain:go_include"),
        single_file = True,
        allow_files = True,
        cfg = "host",
    ),
    "go_root": attr.label(
        providers = ["go_root"],
        default = Label(
            "//go/toolchain:go_root",
        ),
        allow_files = False,
        cfg = "host",
    ),
    "_filter_tags": attr.label(
        default = Label("//go/tools/filter_tags"),
        cfg = "host",
        executable = True,
        single_file = True,
    ),
    "_asm": attr.label(
        default = Label("//go/tools/builders:asm"),
        cfg = "host",
        executable = True,
        single_file = True,
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
        providers = [
            "go_sources",
            "asm_sources",
            "cgo_object",
            "gc_goopts",
        ],
    ),
    "gc_goopts": attr.string_list(),
}

_crosstool_attrs = {
    "_crosstool": attr.label(
        default = Label("//tools/defaults:crosstool"),
    ),
}

go_link_attrs = go_library_attrs + _crosstool_attrs + {
    "gc_linkopts": attr.string_list(),
    "linkstamp": attr.string(),
    "x_defs": attr.string_dict(),
}

go_library_outputs = {
    "lib": "%{name}.a",
}

go_library = rule(
    go_library_impl,
    attrs = go_library_attrs + {
        "cgo_object": attr.label(
            providers = [
                "cgo_obj",
                "cgo_deps",
            ],
        ),
    },
    fragments = ["cpp"],
    outputs = go_library_outputs,
)

go_binary = rule(
    go_binary_impl,
    attrs = go_library_attrs + _crosstool_attrs + go_link_attrs,
    executable = True,
    fragments = ["cpp"],
    outputs = go_library_outputs,
)

go_test = rule(
    go_test_impl,
    attrs = go_library_attrs + _crosstool_attrs + go_link_attrs + {
        "test_generator": attr.label(
            executable = True,
            default = Label(
                "//go/tools:generate_test_main",
            ),
            cfg = "host",
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

def _cgo_filter_srcs_impl(ctx):
  srcs = ctx.files.srcs
  dsts = []
  cmds = []
  for src in srcs:
    stem, _, ext = src.path.rpartition('.')
    dst_basename = "%s.filtered.%s" % (stem, ext)
    dst = ctx.new_file(src, dst_basename)
    cmds += [
        "if '%s' -cgo -quiet '%s'; then" %
            (ctx.executable._filter_tags.path, src.path),
        "  ln -s '%s' '%s'" %
            (_relative_path_from_dir(dst.dirname, src.path), dst.path),
        "else",
        "  echo -n >'%s'" % dst.path,
        "fi",
    ]
    dsts.append(dst)

  if ctx.label.package == "":
    script_name = ctx.label.name + ".CGoFilterSrcs.params"
  else:
    script_name = ctx.label.package + "/" + ctx.label.name + ".CGoFilterSrcs.params"
  f = _emit_generate_params_action(cmds, ctx, script_name)
  ctx.action(
      inputs = [f, ctx.executable._filter_tags] + srcs,
      outputs = dsts,
      command = f.path,
      mnemonic = "CgoFilterSrcs",
  )
  return struct(
      files = set(dsts),
  )

_cgo_filter_srcs = rule(
    implementation = _cgo_filter_srcs_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = cgo_filetype,
        ),
        "_filter_tags": attr.label(
            default = Label("//go/tools/filter_tags"),
            cfg = "host",
            executable = True,
            single_file = True,
        ),
    },
)    

def _cgo_codegen_impl(ctx):
  go_srcs = ctx.files.srcs
  srcs = go_srcs + ctx.files.c_hdrs
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

  p = _pkg_dir(ctx.label.workspace_root, ctx.label.package) + "/"
  if p == "./":
    p = "" # workaround when cgo_library in repository root
  out_dir = (ctx.configuration.genfiles_dir.path + '/' +
             p + ctx.attr.outdir)
  cc = ctx.fragments.cpp.compiler_executable
  cmds = symlink_tree_commands(out_dir + "/src", tree_layout) + [
      'export GOROOT=$(pwd)/' + ctx.file.go_tool.dirname + '/..',
      # We cannot use env for CC because $(CC) on OSX is relative
      # and '../' does not work fine due to symlinks.
      'export CC=$(cd $(dirname {cc}); pwd)/$(basename {cc})'.format(cc=cc),
      'export CXX=$CC',
      'execroot=$(pwd)',
      'filter_tags="$execroot/%s"' % ctx.executable._filter_tags.path,
      'objdir="$(pwd)/%s/gen"' % out_dir,
      'mkdir -p "$objdir"',
      # The working directory must be the directory of the target go package
      # to prevent cgo from prefixing mangled directory names to the output
      # files.
      # TODO(#350): this causes errors if sources are in multiple directories.
      'cd "%s/src/$(dirname %s)"' % (out_dir, _short_path(ctx.files.srcs[0])),
      'unfiltered_go_files=(%s)' % ' '.join(["'%s'" % f.basename for f in go_srcs]),
      'filtered_go_files=()',
      'for file in "${unfiltered_go_files[@]}"; do',
      '  if "$filter_tags" -cgo -quiet "$file"; then',
      '    filtered_go_files+=("$file")',
      '  else',
      '    grep --max-count 1 "^package " "$file" >"$objdir/$(basename "$file" .go).cgo1.go"',
      '    echo -n >"$objdir/$(basename "$file" .go).cgo2.c"',
      '  fi',
      'done',
      '"$GOROOT/bin/go" tool cgo -objdir "$objdir" -- %s "${filtered_go_files[@]}"' %
          ' '.join(['"%s"' % copt for copt in copts]),
      'rm -f $objdir/_cgo_.o $objdir/_cgo_flags']

  f = _emit_generate_params_action(cmds, ctx, out_dir + ".CGoCodeGenFile.params")

  inputs = (srcs + ctx.files.toolchain + ctx.files._crosstool +
            [f, ctx.executable._filter_tags])
  ctx.action(
      inputs = inputs,
      outputs = ctx.outputs.outs,
      mnemonic = "CGoCodeGen",
      progress_message = "CGoCodeGen %s" % ctx.label,
      command = f.path,
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

def _cgo_codegen(name, srcs, c_hdrs=[], deps=[], copts=[], linkopts=[],
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
      copts = copts,
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
                [f, ctx.file.go_tool, ctx.executable._extract_package,
                 ctx.file.cgo_o, ctx.file.sample_go_src]),
      outputs = [ctx.outputs.out],
      command = f.path,
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

def _cgo_genrule_impl(ctx):
  return struct(
    label = ctx.label,
    go_sources = ctx.files.srcs,
    asm_sources = [],
    asm_headers = [],
    cgo_object = ctx.attr.cgo_object,
    direct_deps = ctx.attr.deps,
    gc_goopts = [],
  )

_cgo_genrule = rule(
    _cgo_genrule_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = FileType([".go"])),
        "cgo_object": attr.label(
            providers = [
                "cgo_obj",
                "cgo_deps",
            ],
        ),
        "deps": attr.label_list(
            providers = [
                "direct_deps",
                "go_library_object",
                "transitive_go_importmap",
                "transitive_go_library_object",
                "transitive_cgo_deps",
            ],
        ),
    },
    fragments = ["cpp"],
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
  if _is_darwin_cpu(ctx):
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
  runfiles = ctx.runfiles(collect_data = True)
  runfiles = runfiles.merge(ctx.attr.src.data_runfiles)
  return struct(
      files = set([ctx.outputs.out]),
      cgo_obj = ctx.outputs.out,
      cgo_deps = ctx.attr.cgogen.cgo_deps,
      runfiles = runfiles,
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
        ),
    },
    fragments = ["cpp"],
)

"""Generates _all.o to be archived together with Go objects.

Args:
  src: source static library which contains objects
  cgogen: _cgo_codegen rule which knows the dependency cc_library() rules
    to be linked together with src when we generate the final go binary.
"""

def _setup_cgo_library(name, srcs, cdeps, copts, clinkopts, go_tool, toolchain):
  go_srcs = [s for s in srcs if s.endswith('.go')]
  c_hdrs = [s for s in srcs if any([s.endswith(ext) for ext in hdr_exts])]
  c_srcs = [s for s in srcs if not s in (go_srcs + c_hdrs)]

  # Split cgo files into .go parts and .c parts (plus some other files).
  cgogen = _cgo_codegen(
      name = name + ".cgo",
      srcs = go_srcs,
      c_hdrs = c_hdrs,
      deps = cdeps,
      copts = copts,
      linkopts = clinkopts,
      go_tool = go_tool,
      toolchain = toolchain,
  )

  # Filter c_srcs with build constraints.
  c_filtered_srcs = []
  if len(c_srcs) > 0:
    c_filtered_srcs_name = name + "_filter_cgo_srcs"
    _cgo_filter_srcs(
        name = c_filtered_srcs_name,
        srcs = c_srcs,
    )
    c_filtered_srcs.append(":" + c_filtered_srcs_name)

  pkg_dir = _pkg_dir(
      "external/" + REPOSITORY_NAME[1:] if len(REPOSITORY_NAME) > 1 else "",
      PACKAGE_NAME)

  # Platform-specific settings
  native.config_setting(
      name = name + "_windows_setting",
      values = {
          "cpu": "x64_windows_msvc",
      },
  )
  platform_copts = select({
      ":" + name + "_windows_setting": ["-mthreads"],
      "//conditions:default": ["-pthread"],
  })
  platform_linkopts = select({
      ":" + name + "_windows_setting": ["-mthreads"],
      "//conditions:default": ["-pthread"],
  })

  # Bundles objects into an archive so that _cgo_.o and _all.o can share them.
  native.cc_library(
      name = cgogen.outdir + "/_cgo_lib",
      srcs = cgogen.c_thunks + cgogen.c_exports + c_filtered_srcs + c_hdrs,
      deps = cdeps,
      copts = copts + platform_copts + [
          "-I", pkg_dir,
          "-I", "$(GENDIR)/" + pkg_dir + "/" + cgogen.outdir,
          # The generated thunks often contain unused variables.
          "-Wno-unused-variable",
      ],
      linkopts = clinkopts + platform_linkopts,
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
  return cgogen

def cgo_genrule(name, srcs,
                copts=[],
                clinkopts=[],
                cdeps=[],
                **kwargs):
  cgogen = _setup_cgo_library(
      name = name,
      srcs = srcs,
      cdeps = cdeps,
      copts = copts,
      clinkopts = clinkopts,
      toolchain = None,
      go_tool = None,
  )
  _cgo_genrule(
      name = name,
      srcs = cgogen.go_thunks + [
          cgogen.gotypes,
          cgogen.outdir + "/_cgo_import.go",
      ],
      cgo_object = cgogen.outdir + "/_cgo_object",
      **kwargs
  )

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
  cgogen = _setup_cgo_library(
      name = name,
      srcs = srcs,
      cdeps = cdeps,
      copts = copts,
      clinkopts = clinkopts,
      go_tool = go_tool,
      toolchain = toolchain,
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
