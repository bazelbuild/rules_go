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

load("@io_bazel_rules_go//go/private:common.bzl", "dict_of", "split_srcs", "join_srcs", "pkg_dir")
load("@io_bazel_rules_go//go/private:providers.bzl", "CgoInfo", "GoLibrary")

_CgoCodegen = provider()

def _mangle(ctx, src):
    src_stem, _, src_ext = src.path.rpartition('.')
    mangled_stem = ctx.attr.out_dir + "/" + src_stem.replace('/', '_')
    return mangled_stem, src_ext 

def _c_filter_options(options, blacklist):
  return [opt for opt in options
        if not any([opt.startswith(prefix) for prefix in blacklist])]

def _cgo_codegen_impl(ctx):
  go_toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]
  if not go_toolchain.external_linker:
    fail("Go toolchain does not support cgo")
  linkopts = ctx.attr.linkopts[:]
  copts = go_toolchain.external_linker.c_options + ctx.attr.copts
  deps = depset([], order="topological")
  cgo_export_h = ctx.new_file(ctx.attr.out_dir + "/_cgo_export.h")
  cgo_export_c = ctx.new_file(ctx.attr.out_dir + "/_cgo_export.c")
  cgo_main = ctx.new_file(ctx.attr.out_dir + "/_cgo_main.c")
  cgo_types = ctx.new_file(ctx.attr.out_dir + "/_cgo_gotypes.go")
  out_dir = cgo_main.dirname

  cc = go_toolchain.external_linker.compiler_executable
  args = [go_toolchain.tools.go.path, "-cc", str(cc), "-objdir", out_dir]

  c_outs = depset([cgo_export_h, cgo_export_c])
  go_outs = depset([cgo_types])

  source = split_srcs(ctx.files.srcs)
  for src in source.headers:
      copts += ['-iquote', src.dirname]
  for src in source.go:
    mangled_stem, src_ext = _mangle(ctx, src)
    gen_file = ctx.new_file(mangled_stem + ".cgo1."+src_ext)
    gen_c_file = ctx.new_file(mangled_stem + ".cgo2.c")
    go_outs += [gen_file]
    c_outs += [gen_c_file]
    args += ["-src", gen_file.path + "=" + src.path]
  for src in source.asm:
    mangled_stem, src_ext = _mangle(ctx, src)
    gen_file = ctx.new_file(mangled_stem + ".cgo1."+src_ext)
    go_outs += [gen_file]
    args += ["-src", gen_file.path + "=" + src.path]
  for src in source.c:
    mangled_stem, src_ext = _mangle(ctx, src)
    gen_file = ctx.new_file(mangled_stem + ".cgo1."+src_ext)
    c_outs += [gen_file]
    args += ["-src", gen_file.path + "=" + src.path]

  inputs = ctx.files.srcs + go_toolchain.data.tools + go_toolchain.data.crosstool
  runfiles = ctx.runfiles(collect_data = True)
  for d in ctx.attr.deps:
    inputs += list(d.cc.transitive_headers)
    deps += d.cc.libs
    runfiles = runfiles.merge(d.data_runfiles)
    copts += ['-D' + define for define in d.cc.defines]
    for inc in d.cc.include_directories:
      copts += ['-I', inc]
    for inc in d.cc.quote_include_directories:
      copts += ['-iquote', inc]
    for inc in d.cc.system_include_directories:
      copts += ['-isystem', inc]
    for lib in d.cc.libs:
      if lib.basename.startswith('lib') and lib.basename.endswith('.so'):
        linkopts += ['-L', lib.dirname, '-l', lib.basename[3:-3]]
      else:
        linkopts += [lib.path]
    linkopts += d.cc.link_flags

  # The first -- below is to stop the cgo from processing args, the
  # second is an actual arg to forward to the underlying go tool
  args += ["--", "--"] + copts
  ctx.action(
      inputs = inputs,
      outputs = list(c_outs + go_outs + [cgo_main]),
      mnemonic = "CGoCodeGen",
      progress_message = "CGoCodeGen %s" % ctx.label,
      executable = go_toolchain.tools.cgo,
      arguments = args,
      env = go_toolchain.env + {
          "CGO_LDFLAGS": " ".join(linkopts),
      },
  )
  
  return [
      _CgoCodegen(
          go_files = go_outs,
          main_c = depset([cgo_main]),
          deps = deps,
          exports = depset([cgo_export_h]),
      ),
      DefaultInfo(
          files = depset(),
          runfiles = runfiles,
      ),
      OutputGroupInfo(
          go_files = go_outs,
          c_files = c_outs + source.headers,
          main_c = depset([cgo_main]),
      ),
  ]

_cgo_codegen = rule(
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
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)

def _cgo_import_impl(ctx):
  #TODO: move the dynpackage part into the cgo wrapper so we can stop using shell
  go_toolchain = ctx.toolchains["@io_bazel_rules_go//go:toolchain"]
  command = (
      go_toolchain.tools.go.path + " tool cgo" +
      " -dynout " + ctx.outputs.out.path +
      " -dynimport " + ctx.file.cgo_o.path +
      " -dynpackage $(%s %s)"  % (go_toolchain.tools.extract_package.path,
                                  ctx.files.sample_go_srcs[0].path)
  )
  ctx.action(
      inputs = (go_toolchain.data.tools +
                [go_toolchain.tools.go, go_toolchain.tools.extract_package,
                 ctx.file.cgo_o, ctx.files.sample_go_srcs[0]]),
      outputs = [ctx.outputs.out],
      command = command,
      mnemonic = "CGoImportGen",
      env = go_toolchain.env,
  )
  return struct(
      files = depset([ctx.outputs.out]),
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
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)
"""Generates symbol-import directives for cgo

Args:
  cgo_o: The loadable object to extract dynamic symbols from.
  sample_go_src: A go source which is compiled together with the generated file.
    The generated file will have the same Go package name as this file.
  out: Destination of the generated codes.
"""

def _cgo_collect_info_impl(ctx):
  codegen = ctx.attr.codegen[_CgoCodegen]
  runfiles = ctx.runfiles(collect_data = True)
  runfiles = runfiles.merge(ctx.attr.codegen.data_runfiles)
  
  return [
      DefaultInfo(files = depset(), runfiles = runfiles),
      CgoInfo(
          archive = ctx.file.lib,
          gen_go_srcs = ctx.files.gen_go_srcs,
          deps = ctx.attr.codegen[_CgoCodegen].deps,
          exports = ctx.attr.codegen[_CgoCodegen].exports,
          runfiles = runfiles,
      ),
  ]

_cgo_collect_info = rule(
    _cgo_collect_info_impl,
    attrs = {
        "codegen": attr.label(mandatory = True, providers = [_CgoCodegen]),
        "gen_go_srcs": attr.label_list(mandatory = True, allow_files = [".go"]),
        "lib": attr.label(mandatory = True, allow_single_file = True, providers = ["cc"]),
    },
)
"""No-op rule that collects information from _cgo_codegen and cc_library
info a CgoInfo provider for easy consumption."""

def setup_cgo_library(name, srcs, cdeps, copts, clinkopts):
  cgo_codegen_dir = name + ".cgo.dir"

  # Apply build constraints to source files (both Go and C) but not to header
  # files. Separate filtered Go and C sources.
  
  # Run cgo on the filtered Go files. This will split them into pure Go files
  # and pure C files, plus a few other glue files.
  base_dir = pkg_dir(
      "external/" + REPOSITORY_NAME[1:] if len(REPOSITORY_NAME) > 1 else "",
      PACKAGE_NAME)
  copts = copts + ["-I", base_dir]

  cgo_codegen_name = name + ".cgo_codegen"
  _cgo_codegen(
      name = cgo_codegen_name,
      srcs = srcs,
      deps = cdeps,
      copts = copts,
      linkopts = clinkopts,
      out_dir = cgo_codegen_dir,
      visibility = ["//visibility:private"],
  )

  select_go_files = name + ".select_go_files"
  native.filegroup(
      name = select_go_files,
      srcs = [cgo_codegen_name],
      output_group = "go_files",
      visibility = ["//visibility:private"],
  )

  select_c_files = name + ".select_c_files"
  native.filegroup(
      name = select_c_files,
      srcs = [cgo_codegen_name],
      output_group = "c_files",
      visibility = ["//visibility:private"],
  )

  select_main_c = name + ".select_main_c"
  native.filegroup(
      name = select_main_c,
      srcs = [cgo_codegen_name],
      output_group = "main_c",
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
      srcs = [select_c_files],
      deps = cdeps,
      copts = copts + platform_copts + [
          "-I", "$(BINDIR)/" + base_dir + "/" + cgo_codegen_dir,
          # The generated thunks often contain unused variables.
          "-Wno-unused-variable",
      ],
      linkopts = clinkopts + platform_linkopts,
      linkstatic = 1,
      # _cgo_.o needs all symbols because _cgo_import needs to see them.
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

  cgo_info_name = name + ".cgo_info"
  _cgo_collect_info(
      name = cgo_info_name,
      codegen = cgo_codegen_name,
      gen_go_srcs = [
          select_go_files,
          cgo_import_name,
      ],
      lib = cgo_lib_name,
      visibility = ["//visibility:private"],
  )

  return cgo_info_name
