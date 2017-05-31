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

load("//go/private:common.bzl", "get_go_toolchain", "emit_generate_params_action", "go_env_attrs", "go_filetype", "cgo_filetype", "cc_hdr_filetype", "hdr_exts")
load("//go/private:library.bzl", "go_library")
load("//go/private:binary.bzl", "c_linker_options")

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
                "transitive_go_library_paths",
                "transitive_go_libraries",
                "transitive_cgo_deps",
            ],
        ),
    },
    fragments = ["cpp"],
)

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
      srcs = cgogen.go_thunks + [
          cgogen.gotypes,
          cgogen.outdir + "/_cgo_import.go",
      ],
      cgo_object = cgogen.outdir + "/_cgo_object",
      **kwargs
  )

def _cgo_filter_srcs_impl(ctx):
  go_toolchain = get_go_toolchain(ctx)
  srcs = ctx.files.srcs
  dsts = []
  cmds = []
  for src in srcs:
    stem, _, ext = src.path.rpartition('.')
    dst_basename = "%s.filtered.%s" % (stem, ext)
    dst = ctx.new_file(src, dst_basename)
    cmds += [
        "if '%s' -cgo -quiet '%s'; then" %
            (go_toolchain.filter_tags.path, src.path),
        "  cp '%s' '%s'" % (src.path, dst.path),
        "else",
        "  echo -n >'%s'" % dst.path,
        "fi",
    ]
    dsts.append(dst)

  if ctx.label.package == "":
    script_name = ctx.label.name + ".CGoFilterSrcs.params"
  else:
    script_name = ctx.label.package + "/" + ctx.label.name + ".CGoFilterSrcs.params"
  f = emit_generate_params_action(cmds, ctx, script_name)
  ctx.action(
      inputs = [f, go_toolchain.filter_tags] + srcs,
      outputs = dsts,
      command = f.path,
      mnemonic = "CgoFilterSrcs",
  )
  return struct(
      files = set(dsts),
  )

_cgo_filter_srcs = rule(
    implementation = _cgo_filter_srcs_impl,
    attrs = go_env_attrs + {
        "srcs": attr.label_list(
            allow_files = cgo_filetype,
        ),
    },
    fragments = ["cpp"],
)

def _cgo_codegen_impl(ctx):
  go_toolchain = get_go_toolchain(ctx)
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
    for hdr in ctx.files.c_hdrs:
        copts += ['-iquote', hdr.dirname]
    for inc in d.cc.quote_include_directories:
      copts += ['-iquote', _exec_path(inc)]
    for inc in d.cc.system_include_directories:
      copts += ['-isystem',  _exec_path(inc)]
    for lib in d.cc.libs:
      if lib.basename.startswith('lib') and lib.basename.endswith('.so'):
        linkopts += ['-L', lib.dirname, '-l', lib.basename[3:-3]]
      else:
        linkopts += [lib.path]
    linkopts += d.cc.link_flags

  p = _pkg_dir(ctx.label.workspace_root, ctx.label.package) + "/"
  if p == "./":
    p = "" # workaround when cgo_library in repository root
  out_dir = (ctx.configuration.genfiles_dir.path + '/' +
             p + ctx.attr.outdir)
  cc = ctx.fragments.cpp.compiler_executable
  cmds = [
      # We cannot use env for CC because $(CC) on OSX is relative
      # and '../' does not work fine due to symlinks.
      'export CC=$(cd $(dirname {cc}); pwd)/$(basename {cc})'.format(cc=cc),
      'export CXX=$CC',
      'objdir="%s/gen"' % out_dir,
      'execroot=$(pwd)',
      'mkdir -p "$objdir"',
      'unfiltered_go_files=(%s)' % ' '.join(["'%s'" % f.path for f in go_srcs]),
      'filtered_go_files=()',
      'for file in "${unfiltered_go_files[@]}"; do',
      '  stem=$(basename "$file" .go)',
      '  if %s -cgo -quiet "$file"; then' % go_toolchain.filter_tags.path,
      '    filtered_go_files+=("$file")',
      '  else',
      '    grep --max-count 1 "^package " "$file" >"$objdir/$stem.go"',
      '    echo -n >"$objdir/$stem.c"',
      '  fi',
      'done',
      'if [ ${#filtered_go_files[@]} -eq 0 ]; then',
      '  echo no buildable Go source files in %s >&1' % str(ctx.label),
      '  exit 1',
      'fi',
      '"$GOROOT/bin/go" tool cgo -objdir "$objdir" -- %s "${filtered_go_files[@]}"' %
          ' '.join(['"%s"' % copt for copt in copts]),
      # Rename the outputs using glob so we don't have to understand cgo's mangling
      # TODO(#350): might be fixed by this?.
      'for file in "${filtered_go_files[@]}"; do',
      '  stem=$(basename "$file" .go)',
      '  mv "$objdir/"*"$stem.cgo1.go" "$objdir/$stem.go"',
      '  mv "$objdir/"*"$stem.cgo2.c" "$objdir/$stem.c"',
      'done',
      'rm -f $objdir/_cgo_.o $objdir/_cgo_flags',
    ]

  f = emit_generate_params_action(cmds, ctx, out_dir + ".CGoCodeGenFile.params")

  inputs = (srcs + go_toolchain.tools + go_toolchain.crosstool +
            [f, go_toolchain.filter_tags])
  ctx.action(
      inputs = inputs,
      outputs = ctx.outputs.outs,
      mnemonic = "CGoCodeGen",
      progress_message = "CGoCodeGen %s" % ctx.label,
      command = f.path,
      env = go_toolchain.env + {
          "CGO_LDFLAGS": " ".join(linkopts),
      },
  )
  return struct(
      label = ctx.label,
      files = set(ctx.outputs.outs),
      cgo_deps = deps,
  )

_cgo_codegen_rule = rule(
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

def _cgo_import_impl(ctx):
  go_toolchain = get_go_toolchain(ctx)
  cmds = [
      (go_toolchain.go.path + " tool cgo" +
       " -dynout " + ctx.outputs.out.path +
       " -dynimport " + ctx.file.cgo_o.path +
       " -dynpackage $(%s %s)"  % (go_toolchain.extract_package.path,
                                   ctx.file.sample_go_src.path)),
  ]
  f = emit_generate_params_action(cmds, ctx, ctx.outputs.out.path + ".CGoImportGenFile.params")
  ctx.action(
      inputs = (go_toolchain.tools +
                [f, go_toolchain.go, go_toolchain.extract_package,
                 ctx.file.cgo_o, ctx.file.sample_go_src]),
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
    attrs = go_env_attrs + {
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


def _cgo_codegen(name, srcs, c_hdrs=[], deps=[], copts=[], linkopts=[]):
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
    go_thunks.append(outgen + "/" + basename + ".go")
    c_thunks.append(outgen + "/" + basename + ".c")

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
      copts = copts,
      linkopts = linkopts,
      outdir = outdir,
      outs = outs.go_thunks + outs.c_thunks + outs.c_exports + [
          outs.c_dummy, outs.gotypes,
      ],

      visibility = ["//visibility:private"],
  )
  return outs


"""Generates _all.o to be archived together with Go objects.

Args:
  src: source static library which contains objects
  cgogen: _cgo_codegen rule which knows the dependency cc_library() rules
    to be linked together with src when we generate the final go binary.
"""

def _setup_cgo_library(name, srcs, cdeps, copts, clinkopts):
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

