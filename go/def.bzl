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

load("//go/private:goos_goarch.bzl",     "GOOS_GOARCH")
load("//go/private:go_prefix.bzl",       "go_prefix")
load("//go/private:go_repositories.bzl", "go_repositories")

"""These are bare-bones Go rules.
- No support for build tags
- BUILD file must be written by hand.
- No support for SWIG
- No test sharding or test XML.
"""

# ****************************************************************
# Constants
# ****************************************************************

_DEFAULT_LIB = "go_default_library"

_VENDOR_PREFIX = "/vendor/"

go_filetype = FileType([".go", ".s", ".S"])

# be consistent to cc_library.
hdr_exts = ['.h', '.hh', '.hpp', '.hxx', '.inc']

cc_hdr_filetype = FileType(hdr_exts)

_crosstool_attrs = {
    "_crosstool": attr.label(
        default = Label("//tools/defaults:crosstool"),
    )
}

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
    "go_include": attr.label(
        default = Label("//go/toolchain:go_include"),
        single_file = True,
        allow_files = True,
        cfg = HOST_CFG,
    ),
    "go_root": attr.label(
      providers = ["go_root"],
      default = Label(
        "//go/toolchain:go_root",
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
        "transitive_go_importmap",
        "transitive_go_library_object",
        "transitive_cgo_deps",
      ],
    ),
    "library": attr.label(
      providers = ["go_sources", "asm_sources", "cgo_object"],
    ),
}

go_library_outputs = {
    "lib": "%{name}.a",
}

# ****************************************************************
# Helper Functions
# ****************************************************************

# TODO(bazel-team): it would be nice if Bazel had this built-in.
def symlink_tree_commands(dest_dir, artifacts):
  """Build a list of commands to prepare the dest_dir.

  Args:
    dest_dir (string): The destination directory
    artifacts (dict<string,string>): The mapping of exec-path => path in the dest_dir.

  Returns:
    (list<string>): a list of commands that will setup the symlink tree.

  """
  cmds = [
    "rm -rf " + dest_dir,
    "mkdir -p " + dest_dir,
  ]

  for old_path, new_path in artifacts.items():
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


def _short_path(f):
  """Returns a short path of the given file.
  NOTE: This is a workaround of bazelbuild/bazel#1462

  Args:
    f (File): the input file

  Returns:
    (string): a relative path to the file from its root.

  """
  if not f.root.path:
    return f.path
  prefix = f.root.path
  if prefix[-1] != '/':
    prefix = prefix + '/'
  if not f.path.startswith(prefix):
    fail("file name %s is not prefixed with its root %s", f.path, prefix)
  return f.path[len(prefix):]


def _pkg_dir(workspace_root, package_name):
  """Get directory for the given workspace and package

  Args:
    workspace_root (string): the ctx.label.workspace_root value.
    package_name (string): the ctx.label.package value.

  Returns:
    (string): the package directory.  Default is '.'

  """
  if workspace_root and package_name:
    return workspace_root + "/" + package_name
  if workspace_root:
    return workspace_root
  if package_name:
    return package_name
  return "."


def _c_linker_opts(cpp_fragment, features, blacklist=[]):
  """Build go tool link $CC flags.

  Args:
    cpp_fragment (struct): cxt.fragments.cpp
    features (list<string>): ctx.features
    blacklist (list<string>): Any flags starts with any of these
               prefixes are filtered out from the return value.
  Returns:
    (list<string>): filtered options.

  """
  options = cpp_fragment.compiler_options(features)
  options += cpp_fragment.unfiltered_compiler_options(features)
  options += cpp_fragment.link_options
  options += cpp_fragment.mostly_static_link_options(features, False)

  filtered = []
  for opt in options:
    if any([opt.startswith(prefix) for prefix in blacklist]):
      continue
    filtered.append(opt)
  return filtered


def _go_importpath(prefix, label):
  """Get the path to a library artifact as it should appear for the
  import statement.

  Args:
    prefix (string): the go_prefix value.
    label (Label): the rule label object.

  Returns:
    (string): the path.

  """
  path = prefix
  if path.endswith("/"):
    path = path[:-1]
  if label.package:
    path += "/" + label.package
  if label.name != _DEFAULT_LIB:
    path += "/" + label.name
  if path.rfind(_VENDOR_PREFIX) != -1:
    path = path[len(_VENDOR_PREFIX) + path.rfind(_VENDOR_PREFIX):]
  return path


def _go_outputdir(label, env):
  """Get the directory path where a generated library artifact should be placed.

  Args:
    label (Label): the rule label object.
    env (dict<string,string>): the go_env mappings.  GOOS and GOARCH
    are required.

  Returns:
    (string): the path.

  """
  return "%s_%s/%s" % (env["GOOS"], env["GOARCH"], label.name)


def _go_prefix_from_provider(attr):
  """Get the go-prefix from an attribute.

  Args:
    attr (struct): attr having a 'go_prefix' provider.

  Returns:
    (string): the prefix, always terminated with a slash.

  """
  prefix = attr.go_prefix
  if prefix != "" and not prefix.endswith("/"):
    prefix = prefix + "/"
  return prefix


def _go_root_from_provider(attr):
  """Get the abs path from a 'go_root'-provided attr.

  Args:
    attr (attr): struct having a 'go_root' provider.

  Returns:
    (string): the GOROOT, should be an absolute path.

  NOTE: Cross-compilation requires an absolute path to GOROOT.
        Retrieve the value from the go_root label that was embedded
        into the toolchain BUILD file at the time of repository
        creation.

  """
  return attr.go_root


def _go_env_from_ctx(ctx):
  """Return a map of environment variables for use with actions, based on
  the arguments. Uses the ctx.fragments.cpp.cpu attribute, if present,
  and picks a default of target_os="linux" and target_arch="amd64"
  otherwise.  GOROOT is always included.

  Args:
    ctx (struct): The skylark Context.

  Returns:
    (dict<string,string>): A dict of environment variables for running
    Go tool commands that build for the target OS and architecture.

  """

  bazel_to_go_toolchain = {
    "k8": {
      "GOOS": "linux",
      "GOARCH": "amd64"
    },
    "piii": {
      "GOOS": "linux",
      "GOARCH": "386"
    },
    "darwin": {
      "GOOS": "darwin",
      "GOARCH": "amd64"
    },
    "freebsd": {
      "GOOS": "freebsd",
      "GOARCH": "amd64"
    },
    "armeabi-v7a": {
      "GOOS": "linux",
      "GOARCH": "arm"
    },
    "arm": {
      "GOOS": "linux",
      "GOARCH": "arm"
    },
  }

  default = {
    "GOOS": "linux",
    "GOARCH": "amd64"
  }

  key = ctx.fragments.cpp.cpu
  env =  bazel_to_go_toolchain.get(key, default)

  return env


# ****************************************************************
# Action Emitting Functions
# ****************************************************************

def _emit_params_file_action(ctx, path, mnemonic, cmds):
  """Helper function that writes a potentially long command list to a file.

  Args:
    ctx (struct): The ctx object.
    path (string): the file path where the params file should be written.
    mnemonic (string): the action mnemomic.
    cmds (list<string>): the command list.

  Returns:
    (File): an executable file that runs the command set.

  """
  filename = "%s.%sFile.params" % (path, mnemonic)
  f = ctx.new_file(ctx.configuration.bin_dir, filename)
  ctx.file_action(output = f,
                  content = "\n".join(["set -e"] + cmds),
                  executable = True)
  return f


def _emit_go_asm_action(ctx,
                        toolchain,
                        go_env,
                        go_root,
                        go_include_path,
                        asm_src,
                        out_obj,
                        install_std_library = False):
  """Construct the command line for compiling Go Assembly code.
  Constructs a symlink tree to accomodate for workspace name.

  Args:
    ctx (struct): The skylark Context.
    toolchain (list<File>): from ctx.files.toolchain or equivalent.
    go_env (dict<string,string>): environment for a go command.
    go_root (string): absolute path to GOROOT.
    go_include_path (string): usually $GOROOT/pkg/include.
    asm_src (File): an assembly source file.
    out_obj: the .o artifact that should be produced.
    install_std_library (bool): if true, a 'go install std' will occur.

  """

  args = [
      "$GOROOT/bin/go", "tool", "asm",
      "-I", go_include_path,
      "-o", out_obj.path,
      asm_src.path,
  ]

  cmds = [
      "mkdir -p " + out_obj.dirname,
      " ".join(args),
  ]

  if install_std_library:
    cmds.insert(0, "$GOROOT/bin/go install std") # add -x to see commands

  mnemonic = "GoAsmCompile"
  params = _emit_params_file_action(ctx, out_obj.path, mnemonic, cmds)
  ctx.action(
    mnemonic = mnemonic,
    executable = params,
    inputs = [asm_src] + toolchain,
    outputs = [out_obj],
    env = go_env + {
      "GOROOT": go_root,
    },
  )


def _emit_go_compile_action(ctx,
                            toolchain,
                            go_env,
                            go_root,
                            go_prefix,
                            srcs,
                            out_lib,
                            deps = [],
                            extra_objects = [],
                            install_std_library = False):
  """Construct the command line for compiling Go code.
  Constructs a symlink tree to accomodate for workspace name.

  Args:
    ctx (struct): The skylark Context.
    toolchain (list<File>): from ctx.files.toolchain or equivalent.
    go_env (dict<string,string>): environment for a go command.
    go_root (string): absolute path to GOROOT.
    go_prefix (string): the go import prefix.
    srcs (list<File>): *.go sourcefiles.
    deps (list<struct>): providers:
        .go_library_object<File>
        .transitive_go_importmap<string,string>
    out_lib (File): the .a archive that should be produced.
    extra_objects (list<File>): extra objects to pack into the archive.
    install_std_library (bool): if True, a 'go install std' will occur.

  """

  tree_layout = {}
  inputs = []
  for d in deps:
    actual_path = d.go_library_object.path
    importpath = d.transitive_go_importmap[actual_path]
    tree_layout[actual_path] = importpath + ".a"
    inputs += [d.go_library_object]

  inputs += list(srcs)
  for src in srcs:
    tree_layout[src.path] = go_prefix + src.path

  out_dir = out_lib.path + ".dir"
  out_depth = out_dir.count('/') + 1
  cmds = symlink_tree_commands(out_dir, tree_layout)

  # go install std is smart enough not to redo work and return quickly
  # if the stdlib has already been created.
  if install_std_library:
    cmds += ["$GOROOT/bin/go install std"]

  args = [
    "cd ", out_dir,
    "&&",
    "$GOROOT/bin/go", "tool", "compile",
    "-o", ('../' * out_depth) + out_lib.path,
    "-pack",
    "-I", ".",
  ]

  cmds += [' '.join(args + cmd_helper.template(set(srcs), go_prefix + "%{path}"))]
  extra_inputs = toolchain

  if extra_objects:
    extra_inputs += extra_objects
    objs = ' '.join([c.path for c in extra_objects])
    cmds += ["cd " + ('../' * out_depth),
             "$GOROOT/bin/go tool pack r " + out_lib.path + " " + objs]

  mnemonic = "GoCompile"
  params = _emit_params_file_action(ctx, out_lib.path, mnemonic, cmds)
  ctx.action(
    mnemonic = mnemonic,
    executable = params,
    inputs = inputs + extra_inputs,
    outputs = [out_lib],
    env = go_env + {
      "GOROOT": go_root,
    }
  )


def _emit_go_link_action(ctx,
                         toolchain,
                         crosstool,
                         go_env,
                         go_root,
                         go_prefix,
                         label,
                         importmap,
                         transitive_libs,
                         cgo_deps,
                         configuration_bin_dir_path,
                         cpp_fragment,
                         features,
                         lib,
                         executable,
                         x_defs = {}):
  """Construct the command line for compiling Go code.
  Constructs a symlink tree to accomodate for workspace name.

  Args:
    ctx (struct): The skylark Context.
    toolchain (list<File>): from ctx.files.toolchain or equivalent.
    crosstool (list<File>): from ctx.files._crosstool or equivalent.
    go_env (dict<string,string>): environment for a go command.
    go_root (string): absolute path to GOROOT.
    go_prefix (string): the go import prefix.
    label (Label): the label namespace.
    importmap (dict<string,string>): filename to importpath mappings.
    transitive_libs (iterable<File>): .a dependencies.
    cgo_deps (iterable<File>): .o cgo dependencies.
    configuration_bin_dir_path (string): usually ctx.configuration.bin_dir.path.
    cpp_fragment (struct): usually ctx.fragment.cpp.
    features (struct): usually ctx.features.
    lib (File): the primary input .a library (output of go tool compile).
    executable (File): the primary output of the go linker to generate.
    x_defs (dict<string,string>): -X definitions.

  """

  out_dir = executable.path + ".dir"
  out_depth = out_dir.count('/') + 1
  config_strip = len(configuration_bin_dir_path) + 1
  pkg_depth = executable.dirname[config_strip:].count('/') + 1

  tree_layout = {}
  for l in transitive_libs:
    actual_path = l.path
    importpath = importmap[actual_path]
    tree_layout[l.path] = importpath + ".a"

  for d in cgo_deps:
    tree_layout[d.path] = _short_path(d)

  go_importpath = _go_importpath(go_prefix, label)
  main_archive = importmap[lib.path] + ".a"
  tree_layout[lib.path] = main_archive

  ld = "%s" % cpp_fragment.compiler_executable
  if ld[0] != '/':
    ld = ('../' * out_depth) + ld
  ldflags = _c_linker_opts(cpp_fragment, features) + [
      "-Wl,-rpath,$ORIGIN/" + ("../" * pkg_depth),
      "-L" + go_prefix,
  ]
  for d in cgo_deps:
    if d.basename.endswith('.so'):
      dirname = _short_path(d)[:-len(d.basename)]
      ldflags += ["-Wl,-rpath,$ORIGIN/" + ("../" * pkg_depth) + dirname]

  link_cmd = [
      "$GOROOT/bin/go", "tool", "link",
       "-L", ".",
      "-o", go_importpath,
  ]

  if x_defs:
    link_cmd += [" -X %s='%s' " % (k, v) for k,v in x_defs.items()]

  # workaround for a bug in ld(1) on Mac OS X.
  # http://lists.apple.com/archives/Darwin-dev/2006/Sep/msg00084.html
  # TODO(yugui) Remove this workaround once rules_go stops supporting XCode 7.2
  # or earlier.
  if go_env["GOOS"] != 'darwin':
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
    "cd " + out_dir,
    ' '.join(link_cmd),
    "mv -f " + go_importpath + " " + ("../" * out_depth) + executable.path,
  ]

  inputs = list(transitive_libs) + [lib] + list(cgo_deps) + toolchain + crosstool

  mnemonic = "GoLink"
  params = _emit_params_file_action(ctx, lib.path, mnemonic, cmds)
  ctx.action(
    mnemonic = mnemonic,
    executable = params,
    inputs = inputs,
    outputs = [executable],
    env = go_env + {
      "GOROOT": go_root,
    }
  )

# ****************************************************************
# common build implementations (used by rules and aspects)
# ****************************************************************

def _go_library_build(ctx,
                      label,
                      toolchain,
                      go_prefix,
                      go_env,
                      go_root,
                      go_include_path,
                      srcs,
                      out_lib,
                      cgo_object = None,
                      library = None,
                      deps = [],
                      extra_objects = [],
                      install_std_library = False):
  """Abstracts the context dependent parts of go_library_impl into a separate function.
  Designed to be called from a rule or aspect agnostic to the ctx object.

  Args:
    ctx (struct): The skylark Context.
    label (Label): the ctx.label namespace.
    toolchain (list<File>): from ctx.files.toolchain or equivalent.
    go_env (dict<string,string>): environment for a go command.
    go_root (string): absolute path to GOROOT.
    go_prefix (string): the go import prefix.
    go_include_path (string): usually $GOROOT/pkg/include.
    srcs (list<File>): .go, .s, or .S inputs.
    out_lib (File): the .a archive that should be produced.
    cgo_object (struct): dependent cgo_object.
    deps (list<struct>): Providers:
        .go_library_object<File>
        .transitive_go_importmap<string,string>
    library (struct): Usually from go_test.
        .go_sources (list<File>): list of .go files.
        .asm_sources (list<File>): list of .s or .S files.
        .direct_deps (list<File>): list of .o files.
        .cgo_object (struct): cgo object.
    extra_objects (list<File>): extra objects to pack into the archive.
    install_std_library (bool): if True, a 'go install std' will occur.

  Returns:
    (struct): .direct_deps (list<struct>): deps used by this rule,
              .dylibs (list<File>): .so files needed for runfiles,
              .go_srcs (list<File>): .go files used,
              .asm_srcs (list<File>): .s files used,
              .out_lib (File): generated .a file,
              .transitive_libs (list<File>): transitive .a files,
              .cgo_object (struct): cgo_object used,
              .transitive_cgo_deps (list<File>): transitive .o files,
              .transitive_importmap (dict<string,string>): transitive mappings.

  """

  # Collect and filter source files.
  go_srcs = set([s for s in srcs if s.basename.endswith('.go')])
  asm_srcs = [s for s in srcs if s.basename.endswith('.s') or s.basename.endswith('.S')]

  # Merge in sources from a dependent 'library' target.
  if library:
    go_srcs += library.go_sources
    asm_srcs += library.asm_sources
    deps += library.direct_deps
    if library.cgo_object:
      if cgo_object:
        fail("go_library %s cannot have cgo_object because the package " +
             "already has cgo_object %s" % (label.name, library.cgo_object))
      cgo_object = library.cgo_object

  if not go_srcs:
    fail("may not be empty", "srcs")

  # Start building a transitive cgo_deps object
  transitive_cgo_deps = set([], order="link")

  if cgo_object:
    transitive_cgo_deps += cgo_object.cgo_deps
    extra_objects += [cgo_object.cgo_obj]

  # Build the name of the directory to place the library in
  dirname = _go_outputdir(label, go_env)

  # All asm sources.  Each one gets a new {file}.o and an emit_asm
  # action.  The object file goes into the list of 'extra objects'.
  for asm_src in asm_srcs:
    asm_filename = "%s.dir/%s.o" % (dirname, asm_src.basename[:-2])
    asm_obj = ctx.new_file(asm_src, asm_filename)
    extra_objects += [asm_obj]
    _emit_go_asm_action(ctx = ctx,
                        go_env = go_env,
                        go_root = go_root,
                        toolchain = toolchain,
                        go_include_path = go_include_path,
                        asm_src = asm_src,
                        out_obj = asm_obj,
                        install_std_library = install_std_library)

  _emit_go_compile_action(ctx = ctx,
                          go_env = go_env,
                          go_root = go_root,
                          go_prefix = go_prefix,
                          srcs = go_srcs,
                          deps = deps,
                          toolchain = toolchain,
                          out_lib = out_lib,
                          extra_objects = extra_objects,
                          install_std_library = install_std_library)

  # Build transitive outputs
  transitive_libs = set([out_lib])
  transitive_importmap = {out_lib.path: _go_importpath(go_prefix, label)}
  for dep in deps:
     transitive_libs += dep.transitive_go_library_object
     transitive_cgo_deps += dep.transitive_cgo_deps
     transitive_importmap += dep.transitive_go_importmap

  # Build list of shared object dylibs. these *.so files are needed
  # for runtime.
  dylibs = []
  if cgo_object:
    dylibs += [d for d in cgo_object.cgo_deps if d.path.endswith(".so")]

  return struct(direct_deps = deps,
                dylibs = dylibs,
                go_srcs = go_srcs,
                asm_srcs = asm_srcs,
                out_lib = out_lib,
                transitive_libs = transitive_libs,
                cgo_object = cgo_object,
                transitive_cgo_deps = transitive_cgo_deps,
                transitive_importmap = transitive_importmap)


def _go_binary_build(ctx,
                     label,
                     toolchain,
                     crosstool,
                     cpp_fragment,
                     configuration_bin_dir_path,
                     features,
                     go_env,
                     go_root,
                     go_prefix,
                     go_include_path,
                     srcs,
                     out_lib,
                     executable,
                     deps = [],
                     cgo_object = None,
                     library = None,
                     extra_objects = [],
                     x_defs = {},
                     install_std_library = False):
  """Abstracts the context dependent parts of go_binary_impl into a separate function.
  Designed to be called from a rule or aspect agnostic to the ctx object.

  Args:
    ctx (struct): The skylark Context.
    label (Label): the ctx.label namespace.
    toolchain (list<File>): from ctx.files.toolchain or equivalent.
    crosstool (list<File>): from ctx.files._crosstool or equivalent.
    cpp_fragment (struct): usually ctx.fragment.cpp.
    configuration_bin_dir_path (string): usually ctx.configuration.bin_dir.path.
    features (struct): usually ctx.features.
    go_env (dict<string,string>): environment for a go command.
    go_root (string): absolute path to GOROOT.
    go_prefix (string): the go import prefix.
    go_include_path (string): usually ctx.file.go_include.path ($GOROOT/pkg/include).
    srcs (list<File>): .go, .s, or .S inputs.
    out_lib (File): the .a archive that should be produced.
    executable (File): the binary that should be produced.
    deps (list<struct>): Providers:
        .go_library_object<File>
        .transitive_go_importmap<string,string>
    cgo_object (struct): dependent cgo_object.
    library (struct): Usually from go_test.
        .go_sources (list<File>): list of .go files.
        .asm_sources (list<File>): list of .s or .S files.
        .direct_deps (list<File>): list of .o files.
        .cgo_object (struct): cgo object.
    extra_objects (list<File>): extra objects to pack into the archive.
    x_defs (dict<string,string>): -X definitions.
    install_std_library (bool): if True, a 'go install std' will occur.

  Returns:
    (struct): .executable (File): the generated binary,
              .go_library_result (<struct>): output of go_library_build,
              .cgo_object (struct): cgo_object used.

  """

  result = _go_library_build(
    cgo_object = cgo_object,
    install_std_library = install_std_library,
    ctx = ctx,
    deps = deps,
    go_env = go_env,
    go_include_path = go_include_path,
    go_prefix = go_prefix,
    go_root = go_root,
    label = label,
    library = library,
    out_lib = out_lib,
    srcs = srcs,
    toolchain = toolchain)

  _emit_go_link_action(
    cpp_fragment = cpp_fragment,
    cgo_deps = result.transitive_cgo_deps,
    crosstool = crosstool,
    ctx = ctx,
    executable = executable,
    features = features,
    go_env = go_env,
    go_prefix = go_prefix,
    go_root = go_root,
    importmap = result.transitive_importmap,
    configuration_bin_dir_path = configuration_bin_dir_path,
    label = label,
    lib = result.out_lib,
    transitive_libs = result.transitive_libs,
    x_defs = x_defs,
    toolchain = toolchain,
  )

  return struct(
    cgo_object = result.cgo_object,
    executable = executable,
    go_library_result = result,
  )

# ################################################################
# ASPECTS
# ################################################################

def _xgo_collect_deps(deps):
  """Generate a list of cross-compiled dependencies.

  The values from go_library providers in rule.attr.deps are not
  cross-compiled.  Instead, we need to build our own set of deps from
  the xgo_aspect_result provider.

  Args:
    deps (list<struct>): ctx.rule.attr.deps or equiv.

  Returns:
    (list<struct>): list of cross-compiled deps having providers:
        .go_library_object (File),
        .transitive_go_importmap (dict<string,string>),
        .transitive_go_library_object (list<File>),
        .transitive_cgo_deps (list<File>).

  """
  xdeps = []

  for d in deps:
    results = d.xgo_aspect_result.results
    for build in results:
      if hasattr(build, "go_library_result"):
        lib_result = build.go_library_result
        xdeps.append(struct(
          go_library_object = lib_result.out_lib,
          transitive_go_importmap = lib_result.transitive_importmap,
          transitive_go_library_object = lib_result.transitive_libs,
          transitive_cgo_deps = lib_result.transitive_cgo_deps,
        ))

  return xdeps


def _xgo_collect_runfiles(rule):
  """Generate a list of runfiles from a rule.

  Can't use a ctx.runfiles object (not allowed for aspects).

  Args:
    rule (struct): ctx.rule object.

  Returns:
    (list<File>): list of runfiles.

  """
  files = []

  if hasattr(rule.files, "data"):
    files += [file for file in rule.files.data]

  return files


def _xgo_cgo_object_impl(target, ctx):
  fail("Cross-compilation with cgo-object dependencies is not currently supported.  Failed at %s" % target.label)


def _xgo_cgo_codegen_rule_impl(target, ctx):
  fail("Cross-compilation with cgo-codegen dependencies is not currently supported.  Failed at %s" % target.label)


def _xgo_go_library_impl(target, ctx):
  """go_library_impl aspect implementation.

  Args:
    target (struct): the target rule.
    ctx (struct): the aspect context.

  Returns:
    (struct): with providers:
            .go_library_result (struct): output of go_library_build
            .xgo_lib (File): the cross-compiled library .a file.
            .runfiles (list<File>): list of runfiles.
  )

  """
  rule = ctx.rule
  label = target.label

  os_arch = ctx.attr.os_arch.split("_")
  go_os = os_arch[0]
  go_arch = os_arch[1]
  go_env = {"GOOS": go_os, "GOARCH": go_arch}
  go_prefix = _go_prefix_from_provider(rule.attr.go_prefix)
  go_root = _go_root_from_provider(rule.attr.go_root)
  go_include_path = rule.file.go_include.path

  filename = "_xgo/" + ctx.attr.os_arch + "/" + label.name + ".a"
  xgo_lib = ctx.new_file(filename)

  srcs = rule.files.srcs
  cgo_object = rule.attr.cgo_object if hasattr(rule.attr, "cgo_object") else None
  install_std_library = True,
  features = ctx.features
  library = rule.attr.library if hasattr(rule.attr, "library") else None
  out_lib = xgo_lib
  toolchain = rule.files.toolchain # need x-toolchain?

  deps = _xgo_collect_deps(rule.attr.deps)

  result = _go_library_build(
    ctx,
    label = label,
    srcs = srcs,
    go_prefix = go_prefix,
    go_root = go_root,
    go_env = go_env,
    go_include_path = go_include_path,
    deps = deps,
    cgo_object = cgo_object,
    library = library,
    out_lib = xgo_lib,
    toolchain = toolchain,
    install_std_library = install_std_library)

  return struct(
    go_library_result = result,
    xgo_lib = xgo_lib,
    runfiles = result.dylibs,
  )


def _xgo_go_binary_impl(target, ctx):
  """go_binary_impl aspect implementation.

  Args:
    target (struct): the target rule.
    ctx (struct): the aspect context.

  Returns:
    (struct):
            .go_binary_result (struct): output of go_binary_build
            .xgo_lib (File): the cross-compiled library .a file.
            .xgo_out (File): the cross-compiled library .a file.
            .runfiles (list<File>): list of runfiles.
  )

  """
  rule = ctx.rule

  os_arch = ctx.attr.os_arch.split("_")
  go_os = os_arch[0]
  go_arch = os_arch[1]
  go_env = {"GOOS": go_os, "GOARCH": go_arch}
  go_prefix = _go_prefix_from_provider(rule.attr.go_prefix)
  go_root = _go_root_from_provider(rule.attr.go_root)
  go_include_path = rule.file.go_include.path

  filename = "_xgo/" + ctx.attr.os_arch + "/" + ctx.label.name
  xgo_out = ctx.new_file(filename)
  xgo_lib = ctx.new_file(filename + ".a")

  cgo_object = rule.attr.cgo_object if hasattr(rule.attr, "cgo_object") else None
  configuration_bin_dir_path = ctx.configuration.bin_dir.path
  cpp_fragment = ctx.fragments.cpp
  crosstool = rule.files._crosstool
  install_std_library = True,
  executable = xgo_out
  features = ctx.features
  label = ctx.label
  library = rule.attr.library if hasattr(rule.attr, "library") else None
  out_lib = xgo_lib
  srcs = rule.files.srcs
  toolchain = rule.files.toolchain # need x-toolchain
  x_defs = rule.attr.x_defs # may need to replace these also

  deps = _xgo_collect_deps(rule.attr.deps)

  go_binary_result = _go_binary_build(
    ctx = ctx,
    cgo_object = cgo_object,
    configuration_bin_dir_path = configuration_bin_dir_path,
    cpp_fragment = cpp_fragment,
    crosstool = crosstool,
    install_std_library = install_std_library,
    deps = deps,
    executable = executable,
    features = features,
    go_env = go_env,
    go_include_path = go_include_path,
    go_prefix = go_prefix,
    go_root = go_root,
    label = label,
    library = library,
    out_lib = out_lib,
    srcs = srcs,
    toolchain = toolchain,
    x_defs = x_defs)

  # TODO(pcj): Is this necesssary to add in runfiles?
  #dylibs = go_binary_result.go_library_result.dylibs

  return struct(
    go_binary_result = go_binary_result,
    runfiles = _xgo_collect_runfiles(rule),
    xgo_lib = xgo_lib,
    xgo_out = xgo_out,
  )


def xgo_aspect_impl(target, ctx):
  """xgo_aspect implementation.

  This implementation interrogates the kind of rule in the shadow
  graph being visited.  It then performs a cross-compilation task
  based, either xgo binary or xgo library.  Cgo inputs are not
  supported and will cause the build to fail.  The output of the
  aspect is provided back to the originating rule via the
  xgo_aspect_result provider.  Therefore, a normal rule implementation
  can get all results via `[dep.xgo_aspect_result for dep in
  ctx.attr.deps]`.

  Args:
    target (struct): the target rule.
    ctx (struct): the aspect context.

  Returns:
    (struct):
            .results (list<struct>): direct results
            .files (set<File>): direct file outputs (the cross-compiled binaries)
            .runfiles (set<File>): runfiles.
            .transitive_files (list<File>): transitive outputs
            .transitive_runfiles (list<File>): transitive runfiles.
            .transitive_results (list<struct>)
  )

  """

  # ctx.rule has["attr", "executable", "file", "files", "kind"]
  kind = ctx.rule.kind

  files = []
  runfiles = []
  results = []

  # Switch on the kind of rule we are processing.
  if kind == 'go_binary':
    xgo_binary_result = _xgo_go_binary_impl(target, ctx)
    results.append(xgo_binary_result)
    files.append(xgo_binary_result.xgo_out)
    runfiles += xgo_binary_result.runfiles
  elif kind == 'go_library':
    xgo_library_result = _xgo_go_library_impl(target, ctx)
    results.append(xgo_library_result)
    runfiles += xgo_library_result.runfiles
  elif kind == '_cgo_codegen_rule':
    _xgo_cgo_codegen_rule_impl(target, ctx)
  elif kind == '_cgo_object':
    _xgo_cgo_object_impl(target, ctx)
  else:
    fail("Unexpected aspect dependency kind %s" % kind)

  transitive_files = files
  transitive_runfiles = runfiles
  transitive_results = results
  for d in ctx.rule.attr.deps:
    transitive_files += list(d.xgo_aspect_result.files)
    transitive_runfiles += list(d.xgo_aspect_result.runfiles)
    transitive_results += d.xgo_aspect_result.transitive_results

  return struct(
    xgo_aspect_result = struct(
      files = set(files),
      runfiles = set(runfiles),
      results = results,
      transitive_files = transitive_files,
      transitive_runfiles = transitive_runfiles,
      transitive_results = transitive_results,
    )
  )

xgo_aspect = aspect(
  implementation = xgo_aspect_impl,
  # Propogate across all input deps even though we fail on cgo-related
  # stuff (better to fail than be surprised later).
  attr_aspects = ["deps", "cgo_object", "cgogen"],
  attrs = {
    # This is a skylark "parameterized aspect attribute" implemented
    # in https://github.com/bazelbuild/bazel/commit/74558fcc.  It
    # says: "if any rule attribute declares me in their aspect list,
    # that rule must have a corresponding string attribute matching
    # the name 'os_arch' and must take a value enumerated in these
    # pre-declared values."  Note that it is not private.
    # Parameterized aspect attributes are currently the only way an
    # aspect implementation can get extra information not already
    # provided by shadow nodes.  They also currently can only have
    # type 'string' and must take a known enumeration of values.
    # Fortunately GOOS_GOARCH fits this profile.
    "os_arch": attr.string(values = GOOS_GOARCH),
  },
  fragments = ["cpp"],
)

# ################################################################
# RULES
# ################################################################

# ****************************************************************
# The go_library rule
# ****************************************************************

def go_library_impl(ctx):
  """Implements the go_library() rule."""

  go_env = _go_env_from_ctx(ctx)
  go_prefix = _go_prefix_from_provider(ctx.attr.go_prefix)
  go_root = _go_root_from_provider(ctx.attr.go_root)
  go_include_path = ctx.file.go_include.path
  cgo_object = ctx.attr.cgo_object if hasattr(ctx.attr, "cgo_object") else None

  result = _go_library_build(ctx,
                            label = ctx.label,
                            srcs = ctx.files.srcs,
                            go_prefix = go_prefix,
                            go_root = go_root,
                            go_env = go_env,
                            go_include_path = go_include_path,
                            deps = ctx.attr.deps,
                            cgo_object = cgo_object,
                            library = ctx.attr.library,
                            out_lib = ctx.outputs.lib,
                            toolchain = ctx.files.toolchain,
                            install_std_library = False)

  runfiles = ctx.runfiles(files = result.dylibs, collect_data = True)

  return struct(
    label = ctx.label,
    files = set([result.out_lib]),
    direct_deps = result.direct_deps,
    runfiles = runfiles,
    go_sources = result.go_srcs,
    asm_sources = result.asm_srcs,
    go_library_object = result.out_lib,
    transitive_go_library_object = result.transitive_libs,
    cgo_object = result.cgo_object,
    transitive_cgo_deps = result.transitive_cgo_deps,
    transitive_go_importmap = result.transitive_importmap,
    go_library_result = result,
  )


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
"""Build a go library.

Args:
  data (list<Label>): runfile data files.
  srcs (list<Label>): go sources (.go, .s, .S,)
  deps (list<Label>): list of go_library targets.
  library (Label): singular label providing "go_sources", "asm_sources",
                   and "cgo_object".  Typically used by go_test.
  cgo_object (Label): dependent cgo_object rule.

Results:
  (struct): with providers:
    .label (Label),
    .files (set<File>): .a files
    .direct_deps (list<File>): direct .a inputs.
    .runfiles (runfiles): the ctx.runfiles output.
    .go_sources (list<File>): .go files used in this library.
    .asm_sources (list<File>): .sS files used in this library.
    .go_library_object (File): primary .a output.
    .transitive_go_library_object (set<File>): transitive .a files.
    .cgo_object (struct): cgo_object for this library, or None.
    .transitive_cgo_deps (list<struct>): transitive cgo dependencies.
    .transitive_go_importmap (dict<string,string>): cumulative mappings.
    .go_library_result (struct): output of go_library_build.

Implicit Targets:
  %{name}.a: the library file.

"""

# ****************************************************************
# The go_binary rule
# ****************************************************************


def _go_binary_impl(ctx):

  go_env = _go_env_from_ctx(ctx)
  go_prefix = _go_prefix_from_provider(ctx.attr.go_prefix)
  go_root = _go_root_from_provider(ctx.attr.go_root)
  go_include_path = ctx.file.go_include.path

  cgo_object = ctx.attr.cgo_object if hasattr(ctx.attr, "cgo_object") else None
  library = ctx.attr.library if hasattr(ctx.attr, "library") else None
  out_lib = ctx.outputs.lib
  executable = ctx.outputs.executable
  configuration_bin_dir_path = ctx.configuration.bin_dir.path

  go_binary_result = _go_binary_build(
    cgo_object = cgo_object,
    configuration_bin_dir_path = configuration_bin_dir_path,
    cpp_fragment = ctx.fragments.cpp,
    crosstool = ctx.files._crosstool,
    install_std_library = False,
    ctx = ctx,
    deps = ctx.attr.deps,
    executable = executable,
    features = ctx.features,
    go_env = go_env,
    go_include_path = go_include_path,
    go_prefix = go_prefix,
    go_root = go_root,
    label = ctx.label,
    library = library,
    out_lib = out_lib,
    srcs = ctx.files.srcs,
    toolchain = ctx.files.toolchain,
    x_defs = ctx.attr.x_defs)

  runfiles = ctx.runfiles(collect_data = True,
                          files = ctx.files.data)

  go_library_result = go_binary_result.go_library_result

  return struct(
    files = set([executable, go_library_result.out_lib]),
    runfiles = runfiles,
    cgo_object = go_library_result.cgo_object,
    go_binary_result = go_binary_result,
    go_library_result = go_library_result,
  )


go_binary = rule(
  _go_binary_impl,
  attrs = go_library_attrs + _crosstool_attrs + {
    "stamp": attr.bool(default = False),
    "x_defs": attr.string_dict(),
  },
  executable = True,
  fragments = ["cpp"],
  outputs = go_library_outputs,
)
"""Build a go executable file.

Args: all go_library attributes, plus:
  stamp (bool): apply a timestamp?
  x_defs (string_dict<string,string>): -X definitions.

Results:
  (struct): with:
    .files (set<File>): the binary and .a library files.
    runfiles (runfiles): ctx.runfiles
    cgo_object (struct): same as go_library
    go_binary_result (struct): same as go_library
    .go_library_result (File): same as go_library

Implicit Targets:
  %{name}.a: the library file.

"""


# ****************************************************************
# The go_test rule
# ****************************************************************


def go_test_impl(ctx):
  """go_test_impl implements go testing.
  It emits an action to run the test generator, and then compiles the
  test into a binary.
  """
  go_env = _go_env_from_ctx(ctx)
  go_prefix = _go_prefix_from_provider(ctx.attr.go_prefix)
  go_root = _go_root_from_provider(ctx.attr.go_root)
  go_importpath = _go_importpath(go_prefix, ctx.label)
  main_go = ctx.outputs.main_go

  lib_result = go_library_impl(ctx)
  transitive_libs = lib_result.transitive_go_library_object
  transitive_cgo_deps = lib_result.transitive_cgo_deps
  go_sources = lib_result.go_sources

  args = ["--package", go_importpath,
          "--output", ctx.outputs.main_go.path]
  args += cmd_helper.template(go_sources, "%{path}")

  inputs = list(go_sources) + list(ctx.files.toolchain)
  out_lib = ctx.outputs.main_lib

  ctx.action(mnemonic = "GoTestGenTest",
             inputs = inputs,
             executable = ctx.executable.test_generator,
             outputs = [main_go],
             arguments = args,
             env = go_env + {
               "GOROOT": go_root,
               "RUNDIR": ctx.label.package
             })

  _emit_go_compile_action(ctx = ctx,
                          go_env = go_env,
                          go_root = go_root,
                          go_prefix = go_prefix,
                          toolchain = ctx.files.toolchain,
                          srcs = [main_go],
                          deps = ctx.attr.deps + [lib_result],
                          out_lib = out_lib)

  importmap = lib_result.transitive_go_importmap + {
    out_lib.path: go_importpath + "_main_test"
  }

  _emit_go_link_action(ctx = ctx,
                       label = ctx.label,
                       go_env = go_env,
                       go_prefix = go_prefix,
                       go_root = go_root,
                       x_defs = ctx.attr.x_defs,
                       importmap = importmap,
                       transitive_libs = transitive_libs,
                       cgo_deps = transitive_cgo_deps,
                       configuration_bin_dir_path = ctx.configuration.bin_dir.path,
                       lib = out_lib,
                       executable = ctx.outputs.executable,
                       crosstool = ctx.files._crosstool,
                       toolchain = ctx.files.toolchain,
                       cpp_fragment = ctx.fragments.cpp,
                       features = ctx.features)

  # TODO(bazel-team): the Go tests should do a chdir to the directory
  # holding the data files, so open-source go tests continue to work
  # without code changes.
  runfiles = ctx.runfiles(collect_data = True,
                          files = (ctx.files.data + [ctx.outputs.executable] +
                                   list(lib_result.runfiles.files)))

  return struct(runfiles = runfiles)


go_test = rule(
    go_test_impl,
    attrs = go_library_attrs + _crosstool_attrs + {
        "test_generator": attr.label(
            executable = True,
            default = Label(
                "//go/tools:generate_test_main",
            ),
            cfg = HOST_CFG,
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


# ****************************************************************
# The xgo_binary rule
# ****************************************************************


def xgo_binary_impl(ctx):
  files = set()
  runfiles = set()

  # By this time, all aspects finished processing and have stored
  # their results in the 'xgo_aspect_result' provider slot of each
  # dep.

  for dep in ctx.attr.deps:
    result = dep.xgo_aspect_result
    files = files | result.transitive_files
    runfiles = runfiles | result.transitive_runfiles

  return struct(
    files = files,
    runfiles = ctx.runfiles(files = list(runfiles)),
  )

xgo_binary = rule(
  xgo_binary_impl,
  attrs = {
    "deps": attr.label_list(
      providers = [
        "xgo_aspect_result",
      ],
      aspects = [xgo_aspect],
    ),
    "os_arch": attr.string(default = "linux_arm64"),
  },
  fragments = ["cpp"],
)
"""Generates a cross-compiled binary object(s).

Depend on this rule like a filegroup to pull the list of generated
files.

Args:
  deps (list<Label>): go_binary dependencies.
  os_arch (string): The desired platform in the form "GOOS_GOARCH".
                    Must be one of the values in goos_goarch.bzl file.

"""


# ****************************************************************
# The cgo_codegen rule
# ****************************************************************


def _exec_path(path):
  if path.startswith('/'):
    return path
  return '${execroot}/' + path

def _cgo_codegen_impl(ctx):

  go_env = _go_env_from_ctx(ctx)
  go_root = _go_root_from_provider(ctx.attr.go_root)

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

  # collect files from $(SRCDIR), $(GENDIR) and $(BINDIR)
  tree_layout = {}
  for s in srcs:
    tree_layout[s.path] = _short_path(s)

  out_dir = (ctx.configuration.genfiles_dir.path + '/' +
             _pkg_dir(ctx.label.workspace_root, ctx.label.package) + "/" +
             ctx.attr.outdir)
  cc = ctx.fragments.cpp.compiler_executable
  cmds = symlink_tree_commands(out_dir + "/src", tree_layout) + [
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

  mnemonic = "CGoCodeGen"
  params = _emit_params_file_action(ctx, out_dir, mnemonic, cmds)
  ctx.action(
    mnemonic = mnemonic,
    executable = params,
    inputs = srcs + ctx.files.toolchain + ctx.files._crosstool,
    outputs = ctx.outputs.outs,
    progress_message = "%s %s" % (mnemonic, ctx.label),
    env = go_env + {
      "GOROOT": go_root,
      "CGO_LDFLAGS": " ".join(linkopts),
    })

  return struct(
      label = ctx.label,
      files = set(ctx.outputs.outs),
      cgo_deps = deps,
  )

_cgo_codegen_rule = rule(
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

  _cgo_codegen_rule(
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


# ****************************************************************
# The cgo_import rule
# ****************************************************************


def _cgo_import_impl(ctx):
  go_env = _go_env_from_ctx(ctx)
  go_root = _go_root_from_provider(ctx.attr.go_root)

  cmds = [
      ("$GOROOT/bin/go tool cgo" +
       " -dynout " + ctx.outputs.out.path +
       " -dynimport " + ctx.file.cgo_o.path +
       " -dynpackage $(%s %s)"  % (ctx.executable._extract_package.path,
                                   ctx.file.sample_go_src.path)),
  ]

  mnemonic = "CGoImportGen"
  params = _emit_params_file_action(ctx, ctx.outputs.out.path, mnemonic, cmds)
  ctx.action(
    mnemonic = mnemonic,
    executable = params,
    inputs = (ctx.files.toolchain +
              [ctx.file.go_tool, ctx.executable._extract_package,
               ctx.file.cgo_o, ctx.file.sample_go_src]),
    outputs = [ctx.outputs.out],
    env = go_env + {
      "GOROOT": go_root,
    }
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
  fragments = ["cpp"],
)
"""Generates symbol-import directives for cgo

Args:
  cgo_o: The loadable object to extract dynamic symbols from.
  sample_go_src: A go source which is compiled together with the generated file.
    The generated file will have the same Go package name as this file.
  out: Destination of the generated codes.
"""


# ****************************************************************
# The cgo_object rule
# ****************************************************************


def _cgo_object_impl(ctx):
  cpp_fragment = ctx.fragments.cpp
  linker_blacklist = [
    # never link any dependency libraries
    "-l", "-L",
    # manage flags to ld(1) by ourselves
    "-Wl,",
  ]
  arguments = _c_linker_opts(cpp_fragment, ctx.features, linker_blacklist)
  arguments += [
      "-o", ctx.outputs.out.path,
      "-nostdlib",
      "-Wl,-r",
  ]

  if cpp_fragment.cpu == "darwin":
    arguments += ["-shared", "-Wl,-all_load"]
  else:
    arguments += ["-Wl,-whole-archive"]

  lo = ctx.files.src[-1]
  arguments += [lo.path]

  ctx.action(mnemonic = "CGoObject",
             inputs = [lo] + ctx.files._crosstool,
             outputs = [ctx.outputs.out],
             executable = ctx.fragments.cpp.compiler_executable,
             arguments = arguments,
             progress_message = "Linking %s" % _short_path(ctx.outputs.out))

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
