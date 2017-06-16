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

load("@io_bazel_rules_go//go/private:common.bzl", "get_go_toolchain", "emit_generate_params_action", "go_filetype", "cgo_filetype", "cc_hdr_filetype", "hdr_exts", "pkg_dir")
load("@io_bazel_rules_go//go/private:library.bzl", "go_library")
load("@io_bazel_rules_go//go/private:binary.bzl", "c_linker_options")

def cgo_genrule(tags=[], **kwargs):
  return cgo_library(tags=tags+["manual"], **kwargs)

def cgo_library(name, srcs,
                go_toolchain=None,
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
  )

  go_library(
      name = name,
      srcs = cgogen.go_srcs,
      cgo_object = cgogen.cgo_object,
      **kwargs
  )

def _cgo_select_go_files_impl(ctx):
  return struct(files = ctx.attr.dep.go_files)

_cgo_select_go_files = rule(_cgo_select_go_files_impl, attrs = {"dep": attr.label()})

def _cgo_select_main_c_impl(ctx):
  return struct(files = ctx.attr.dep.main_c)

_cgo_select_main_c = rule(_cgo_select_main_c_impl, attrs = {"dep": attr.label()})

def _cgo_codegen_impl(ctx):
  go_toolchain = get_go_toolchain(ctx)
  srcs = ctx.files.srcs
  go_srcs = [src for src in srcs if src.basename.endswith(".go")]
  c_hdrs = [src for src in srcs if any([src.basename.endswith(ext) for ext in hdr_exts])]
  other_srcs = [src for src in srcs if not src in go_srcs and not src in c_hdrs]
  linkopts = ctx.attr.linkopts
  copts = ctx.fragments.cpp.c_options + ctx.attr.copts
  deps = set([], order="link")
  cgo_export_h = ctx.new_file(ctx.attr.out_dir + "/_cgo_export.h")
  cgo_export_c = ctx.new_file(ctx.attr.out_dir + "/_cgo_export.c")
  cgo_main = ctx.new_file(ctx.attr.out_dir + "/_cgo_main.c")
  cgo_types = ctx.new_file(ctx.attr.out_dir + "/_cgo_gotypes.go")

  c_hdrs += [cgo_export_h]
  c_outs = depset(c_hdrs) + [cgo_export_c]
  go_outs = depset([cgo_types])
  outputs = [ cgo_export_h, cgo_export_c, cgo_main, cgo_types]
  out_dir = cgo_main.dirname

  for hdr in c_hdrs:
    copts += ['-iquote', hdr.dirname]
  for d in ctx.attr.deps:
    srcs += list(d.cc.transitive_headers)
    deps += d.cc.libs
    copts += ['-D' + define for define in d.cc.defines]
    for inc in d.cc.include_directories:
      copts += ['-I', _exec_path(inc)]
    for inc in d.cc.quote_include_directories:
      copts += ['-iquote', _exec_path(inc)]
    for inc in d.cc.system_include_directories:
      copts += ['-isystem', _exec_path(inc)]
    for lib in d.cc.libs:
      if lib.basename.startswith('lib') and lib.basename.endswith('.so'):
        linkopts += ['-L', lib.dirname, '-l', lib.basename[3:-3]]
      else:
        linkopts += [lib.path]
    linkopts += d.cc.link_flags

  cc = ctx.fragments.cpp.compiler_executable
  cmds = [
      # We cannot use env for CC because $(CC) on OSX is relative
      # and '../' does not work fine due to symlinks.
      'export CC=$(cd $(dirname {cc}); pwd)/$(basename {cc})'.format(cc=cc),
      'export CXX=$CC',
      "objdir='%s'" % out_dir,
      'execroot=$(pwd)',
      'mkdir -p "$objdir"',
      # Apply build constraints to .go sources before passing them to cgo.
      # We have to do this here because _cgo_filter_srcs creates empty files
      # which lack package declarations.
      'unfiltered_go_files=(%s)' % ' '.join(["'%s'" % f.path for f in go_srcs]),
      'filtered_go_files=()',
      'for file in "${unfiltered_go_files[@]}"; do',
      '  if %s -cgo -quiet "$file"; then' % go_toolchain.filter_tags.path,
      '    filtered_go_files+=("$file")',
      '  fi',
      'done',
      'if [ ${#filtered_go_files[@]} -eq 0 ]; then',
      '  echo no buildable Go source files in %s >&1' % str(ctx.label),
      '  exit 1',
      'fi',
      '"$GOROOT/bin/go" tool cgo -objdir "$objdir" -- %s "${filtered_go_files[@]}"' %
          ' '.join(['"%s"' % copt for copt in copts]),
      'rm -rf "$objdir"/{_cgo_.o,_cgo_flags}',
  ]

  # Move generated files into place, and generate empty files for the sources
  # that were filtered out. We emit explicit commands for each file in order
  # to avoid implement name demangling in bash.
  for s in go_srcs:
    name, _, _ = s.basename.rpartition('.')
    src_stem, _, _ = s.path.rpartition('.')
    mangled_stem = out_dir + "/" + src_stem.replace('/', '_')
    gen_go_file = ctx.new_file(name + ".cgo1.go")
    gen_c_file = ctx.new_file(name + ".cgo2.c")
    cmds += [
      "if [ -f '%s' ]; then" % (mangled_stem + ".cgo1.go"),
      "  mv '%s' '%s'" % (mangled_stem + ".cgo1.go", gen_go_file.path),
      "  mv '%s' '%s'" % (mangled_stem + ".cgo2.c", gen_c_file.path),
      "else",
      "  grep --max-count=1 '^package ' '%s' >'%s'" % (s.path, gen_go_file.path),
      "  echo -n >'%s'" % gen_c_file.path,
      "fi",
    ]
    outputs += [gen_go_file, gen_c_file]
    c_outs += [gen_c_file]
    go_outs += [gen_go_file]

  for src in other_srcs:
    base, _, ext = src.basename.rpartition(".")
    dst = ctx.new_file(base + "." + ctx.label.name +"." + ext)
    cmds += [
      "if '%s' -cgo -quiet '%s'; then" %
          (go_toolchain.filter_tags.path, src.path),
      "  cp '%s' '%s'" % (src.path, dst.path),
      "else",
      "  echo -n >'%s'" % dst.path,
      "fi",
    ]
    outputs += [dst]
    c_outs += [dst]

  f = emit_generate_params_action(cmds, ctx, ctx.label.name + ".CGoCodeGenFile.params")

  inputs = srcs + go_toolchain.tools + go_toolchain.crosstool + [f, go_toolchain.filter_tags]
  ctx.action(
      inputs = inputs,
      outputs = outputs,
      mnemonic = "CGoCodeGen",
      progress_message = "CGoCodeGen %s" % ctx.label,
      command = f.path,
      env = go_toolchain.env + {
          "CGO_LDFLAGS": " ".join(linkopts),
      },
  )
  return struct(
      label = ctx.label,
      files = c_outs,
      go_files = go_outs,
      main_c = depset([cgo_main]),
      cgo_deps = deps,
  )

_cgo_codegen_rule = rule(
    _cgo_codegen_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "deps": attr.label_list(
            allow_files = False,
            providers = ["cc"],
        ),
        "copts": attr.string_list(),
        "linkopts": attr.string_list(),
        "out_dir": attr.string(mandatory = True),
        #TODO(toolchains): Remove _toolchain attribute when real toolchains arrive
        "_go_toolchain": attr.label(default = Label("@io_bazel_rules_go_toolchain//:go_toolchain")),
    },
    fragments = ["cpp"],
)

def _cgo_import_impl(ctx):
  go_toolchain = get_go_toolchain(ctx)
  cmds = [
      (go_toolchain.go.path + " tool cgo" +
       " -dynout " + ctx.outputs.out.path +
       " -dynimport " + ctx.file.cgo_o.path +
       " -dynpackage $(%s %s)"  % (go_toolchain.extract_package.path,
                                   ctx.files.sample_go_srcs[0].path)),
  ]
  f = emit_generate_params_action(cmds, ctx, ctx.outputs.out.path + ".CGoImportGenFile.params")
  ctx.action(
      inputs = (go_toolchain.tools +
                [f, go_toolchain.go, go_toolchain.extract_package,
                 ctx.file.cgo_o, ctx.files.sample_go_srcs[0]]),
      outputs = [ctx.outputs.out],
      command = f.path,
      mnemonic = "CGoImportGen",
      env = go_toolchain.env,
  )
  return struct(
      files = set([ctx.outputs.out]),
  )

_cgo_import = rule(
    _cgo_import_impl,
    attrs = {
        "cgo_o": attr.label(
            allow_files = True,
            single_file = True,
        ),
        "sample_go_srcs": attr.label_list(allow_files = True),
        "out": attr.output(
            mandatory = True,
        ),
        #TODO(toolchains): Remove _toolchain attribute when real toolchains arrive
        "_go_toolchain": attr.label(default = Label("@io_bazel_rules_go_toolchain//:go_toolchain")),
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
  go_toolchain = get_go_toolchain(ctx)
  arguments = c_linker_options(ctx, blacklist=[
      # never link any dependency libraries
      "-l", "-L",
      # manage flags to ld(1) by ourselves
      "-Wl,"])
  arguments += [
      "-o", ctx.outputs.out.path,
      "-nostdlib",
      "-Wl,-r",
  ] + go_toolchain.cgo_link_flags

  lo = ctx.files.src[-1]
  arguments += [lo.path]

  ctx.action(
      inputs = [lo] + go_toolchain.crosstool,
      outputs = [ctx.outputs.out],
      mnemonic = "CGoObject",
      progress_message = "Linking %s" % ctx.outputs.out.short_path,
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
        ),
        #TODO(toolchains): Remove _toolchain attribute when real toolchains arrive
        "_go_toolchain": attr.label(default = Label("@io_bazel_rules_go_toolchain//:go_toolchain")),
    },
    fragments = ["cpp"],
)


def _exec_path(path):
  if path.startswith('/'):
    return path
  return '${execroot}/' + path


"""Generates _all.o to be archived together with Go objects.

Args:
  src: source static library which contains objects
  cgogen: _cgo_codegen rule which knows the dependency cc_library() rules
    to be linked together with src when we generate the final go binary.
"""

def _setup_cgo_library(name, srcs, cdeps, copts, clinkopts):
  cgo_codegen_dir = name + ".cgo.dir"

  # Apply build constraints to source files (both Go and C) but not to header
  # files. Separate filtered Go and C sources.
  
  # Run cgo on the filtered Go files. This will split them into pure Go files
  # and pure C files, plus a few other glue files.
  base_dir = pkg_dir(
      "external/" + REPOSITORY_NAME[1:] if len(REPOSITORY_NAME) > 1 else "",
      PACKAGE_NAME)
  copts += ["-I", base_dir]

  cgo_codegen_name = name + ".cgo_codegen"
  _cgo_codegen_rule(
      name = cgo_codegen_name,
      srcs = srcs,
      deps = cdeps,
      copts = copts,
      linkopts = clinkopts,
      out_dir = cgo_codegen_dir,
      visibility = ["//visibility:private"],
  )

  select_go_files = name + ".select_go_files"
  _cgo_select_go_files(
      name = select_go_files,
      dep = cgo_codegen_name,
      visibility = ["//visibility:private"],
  )

  select_main_c = name + ".select_main_c"
  _cgo_select_main_c(
      name = select_main_c,
      dep = cgo_codegen_name,
      visibility = ["//visibility:private"],
  )

  # Compile C sources and generated files into a library. This will be linked
  # into binaries that depend on this cgo_library. It will also be used
  # in _cgo_.o.
  platform_copts = select({
      "@io_bazel_rules_go//go/platform:windows_amd64": ["-mthreads"],
      "//conditions:default": ["-pthread"],
  })
  platform_linkopts = platform_copts

  cgo_lib_name = name + ".cgo_c_lib"
  native.cc_library(
      name = cgo_lib_name,
      srcs = [cgo_codegen_name],
      deps = cdeps,
      copts = copts + platform_copts + [
          "-I", "$(BINDIR)/" + base_dir + "/" + cgo_codegen_dir,
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

  # Create a loadable object with no undefined references. cgo reads this
  # when it generates _cgo_import.go.
  cgo_o_name = name + "._cgo_.o"
  native.cc_binary(
      name = cgo_o_name,
      srcs = [select_main_c],
      deps = cdeps + [cgo_lib_name],
      copts = copts,
      linkopts = clinkopts,
      visibility = ["//visibility:private"],
  )

  # Create a Go file which imports symbols from the C library.
  cgo_import_name = name + ".cgo_import"
  _cgo_import(
      name = cgo_import_name,
      cgo_o = cgo_o_name,
      sample_go_srcs = [select_go_files],
      out = cgo_codegen_dir + "/_cgo_import.go",
      visibility = ["//visibility:private"],
  )

  # Link the library into a relocatable .o file that can be linked into the
  # final binary.
  all_o_name = name + "._all.o"
  _cgo_object(
      name = all_o_name,
      src = cgo_lib_name,
      out = cgo_codegen_dir + "/_all.o",
      cgogen = cgo_codegen_name,
      visibility = ["//visibility:private"],
  )

  return struct(
      name = name,
      go_srcs = [
          select_go_files,
          cgo_import_name,
      ],
      cgo_object = all_o_name,
  )
