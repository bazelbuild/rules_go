# The MIT License (MIT)
# Copyright © 2018 Jeff Hodges <jeff@somethingsimilar.com>

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the “Software”), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_context", "go_path")
load("@io_bazel_rules_go//go/private:providers.bzl", "GoLibrary", "GoPath")

_MOCKGEN_TOOL = "@com_github_golang_mock//mockgen"
_MOCKGEN_MODEL_LIB = "@com_github_golang_mock//mockgen/model:go_default_library"

def _gomock_source_impl(ctx):
    go_ctx = go_context(ctx)
    gopath = "$(pwd)/" + ctx.bin_dir.path + "/" + ctx.attr.gopath_dep[GoPath].gopath

    # passed in source needs to be in gopath to not trigger module mode
    args = ["-source", gopath + "/src/" + ctx.attr.library[GoLibrary].importmap + "/" + ctx.file.source.basename]

    args, needed_files = _handle_shared_args(ctx, args)

    if len(ctx.attr.aux_files) > 0:
        aux_files = []
        for pkg, files in ctx.attr.aux_files.items():
            for f in files:
                mapped_f = gopath + "/src/" + ctx.attr.library[GoLibrary].importmap + "/" + f
                aux_files.append("{0}={1}".format(pkg, mapped_f))
        args += ["-aux_files", ",".join(aux_files)]

    inputs = (
        ctx.attr.gopath_dep.files.to_list() + needed_files +
        go_ctx.sdk.headers + go_ctx.sdk.srcs + go_ctx.sdk.tools
    ) + [ctx.file.source]

    # We can use the go binary from the stdlib for most of the environment
    # variables, but our GOPATH is specific to the library target we were given.
    ctx.actions.run_shell(
        outputs = [ctx.outputs.out],
        inputs = inputs,
        tools = [
            ctx.file.mockgen_tool,
            go_ctx.go,
        ],
        command = """
           source <($PWD/{godir}/go env) &&
           export PATH=$GOROOT/bin:$PWD/{godir}:$PATH &&
           export GOPATH={gopath} &&
           mkdir -p .gocache &&
           export GOCACHE=$PWD/.gocache &&
           {cmd} {args} > {out}
        """.format(
            godir = go_ctx.go.path[:-1 - len(go_ctx.go.basename)],
            gopath = gopath,
            cmd = "$(pwd)/" + ctx.file.mockgen_tool.path,
            args = " ".join(args),
            out = ctx.outputs.out.path,
            mnemonic = "GoMockSourceGen",
        ),
        env = {
            "GO111MODULE": "off",  # explicitly relying on passed in go_path to not download modules while doing codegen
        },
    )

_gomock_source = rule(
    _gomock_source_impl,
    attrs = {
        "library": attr.label(
            doc = "The target the Go library is at to look for the interfaces in. When this is set and source is not set, mockgen will use its reflect code to generate the mocks. If source is set, its dependencies will be included in the GOPATH that mockgen will be run in.",
            providers = [GoLibrary],
            mandatory = True,
        ),
        "source": attr.label(
            doc = "A Go source file to find all the interfaces to generate mocks for. See also the docs for library.",
            mandatory = False,
            allow_single_file = True,
        ),
        "out": attr.output(
            doc = "The new Go file to emit the generated mocks into",
            mandatory = True,
        ),
        "interfaces": attr.string_list(
            allow_empty = False,
            doc = "Ignored. If `source` is not set, this would be the list of Go interfaces to generate mocks for.",
            mandatory = True,
        ),
        "aux_files": attr.string_list_dict(
            default = {},
            doc = "A map from packages to auxilliary Go source files to load for those packages.",
        ),
        "package": attr.string(
            doc = "The name of the package the generated mocks should be in. If not specified, uses mockgen's default.",
        ),
        "self_package": attr.string(
            doc = "The full package import path for the generated code. The purpose of this flag is to prevent import cycles in the generated code by trying to include its own package. This can happen if the mock's package is set to one of its inputs (usually the main one) and the output is stdio so mockgen cannot detect the final output package. Setting this flag will then tell mockgen which import to exclude.",
        ),
        "imports": attr.string_dict(
            doc = "Dictionary of name-path pairs of explicit imports to use.",
        ),
        "mock_names": attr.string_dict(
            doc = "Dictionary of interface name to mock name pairs to change the output names of the mock objects. Mock names default to 'Mock' prepended to the name of the interface.",
            default = {},
        ),
        "copyright_file": attr.label(
            doc = "Optional file containing copyright to prepend to the generated contents.",
            allow_single_file = True,
            mandatory = False,
        ),
        "gopath_dep": attr.label(
            doc = "The go_path label to use to create the GOPATH for the given library. Will be set correctly by the gomock macro, so you don't need to set it.",
            providers = [GoPath],
            mandatory = False,
        ),
        "mockgen_tool": attr.label(
            doc = "The mockgen tool to run",
            default = Label(_MOCKGEN_TOOL),
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            mandatory = False,
        ),
        "_go_context_data": attr.label(
            default = "@io_bazel_rules_go//:go_context_data",
        ),
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)

def gomock(name, library, out, **kwargs):
    mockgen_tool = _MOCKGEN_TOOL
    if kwargs.get("mockgen_tool", None):
        mockgen_tool = kwargs["mockgen_tool"]

    if kwargs.get("source", None):
        gopath_name = name + "_gomock_gopath"
        go_path(
            name = gopath_name,
            deps = [library, mockgen_tool],
        )
        _gomock_source(
            name = name,
            library = library,
            gopath_dep = gopath_name,
            out = out,
            **kwargs
        )
    else:
        _gomock_reflect(
            name = name,
            library = library,
            out = out,
            mockgen_tool = mockgen_tool,
            **kwargs
        )

def _gomock_reflect(name, library, out, mockgen_tool, **kwargs):
    interfaces = kwargs.pop("interfaces", None)

    mockgen_model_lib = _MOCKGEN_MODEL_LIB
    if kwargs.get("mockgen_model_library", None):
        mockgen_model_lib = kwargs["mockgen_model_library"]

    prog_src = name + "_gomock_prog"
    prog_src_out = prog_src + ".go"
    _gomock_prog_gen(
        name = prog_src,
        interfaces = interfaces,
        library = library,
        out = prog_src_out,
        mockgen_tool = mockgen_tool,
    )
    prog_bin = name + "_gomock_prog_bin"
    go_binary(
        name = prog_bin,
        srcs = [prog_src_out],
        deps = [library, mockgen_model_lib],
    )
    _gomock_prog_exec(
        name = name,
        interfaces = interfaces,
        library = library,
        out = out,
        prog_bin = prog_bin,
        mockgen_tool = mockgen_tool,
        **kwargs
    )

def _gomock_prog_gen_impl(ctx):
    args = ["-prog_only"]
    args += [ctx.attr.library[GoLibrary].importpath]
    args += [",".join(ctx.attr.interfaces)]

    cmd = ctx.file.mockgen_tool
    out = ctx.outputs.out
    ctx.actions.run_shell(
        outputs = [out],
        tools = [cmd],
        command = """
           {cmd} {args} > {out}
        """.format(
            cmd = "$(pwd)/" + cmd.path,
            args = " ".join(args),
            out = out.path,
        ),
        mnemonic = "GoMockReflectProgOnlyGen",
    )

_gomock_prog_gen = rule(
    _gomock_prog_gen_impl,
    attrs = {
        "library": attr.label(
            doc = "The target the Go library is at to look for the interfaces in. When this is set and source is not set, mockgen will use its reflect code to generate the mocks. If source is set, its dependencies will be included in the GOPATH that mockgen will be run in.",
            providers = [GoLibrary],
            mandatory = True,
        ),
        "out": attr.output(
            doc = "The new Go source file put the mock generator code",
            mandatory = True,
        ),
        "interfaces": attr.string_list(
            allow_empty = False,
            doc = "The names of the Go interfaces to generate mocks for. If not set, all of the interfaces in the library or source file will have mocks generated for them.",
            mandatory = True,
        ),
        "mockgen_tool": attr.label(
            doc = "The mockgen tool to run",
            default = Label(_MOCKGEN_TOOL),
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            mandatory = False,
        ),
        "_go_context_data": attr.label(
            default = "@io_bazel_rules_go//:go_context_data",
        ),
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)

def _gomock_prog_exec_impl(ctx):
    args = ["-exec_only", ctx.file.prog_bin.path]
    args, needed_files = _handle_shared_args(ctx, args)

    # annoyingly, the interfaces join has to go after the importpath so we can't
    # share those.
    args += [ctx.attr.library[GoLibrary].importpath]
    args += [",".join(ctx.attr.interfaces)]

    ctx.actions.run_shell(
        outputs = [ctx.outputs.out],
        inputs = [ctx.file.prog_bin] + needed_files,
        tools = [ctx.file.mockgen_tool],
        command = """{cmd} {args} > {out}""".format(
            cmd = "$(pwd)/" + ctx.file.mockgen_tool.path,
            args = " ".join(args),
            out = ctx.outputs.out.path,
        ),
        env = {
            # GOCACHE is required starting in Go 1.12
            "GOCACHE": "./.gocache",
        },
        mnemonic = "GoMockReflectExecOnlyGen",
    )

_gomock_prog_exec = rule(
    _gomock_prog_exec_impl,
    attrs = {
        "library": attr.label(
            doc = "The target the Go library is at to look for the interfaces in. When this is set and source is not set, mockgen will use its reflect code to generate the mocks. If source is set, its dependencies will be included in the GOPATH that mockgen will be run in.",
            providers = [GoLibrary],
            mandatory = True,
        ),
        "out": attr.output(
            doc = "The new Go source file to put the generated mock code",
            mandatory = True,
        ),
        "interfaces": attr.string_list(
            allow_empty = False,
            doc = "The names of the Go interfaces to generate mocks for. If not set, all of the interfaces in the library or source file will have mocks generated for them.",
            mandatory = True,
        ),
        "package": attr.string(
            doc = "The name of the package the generated mocks should be in. If not specified, uses mockgen's default.",
        ),
        "self_package": attr.string(
            doc = "The full package import path for the generated code. The purpose of this flag is to prevent import cycles in the generated code by trying to include its own package. This can happen if the mock's package is set to one of its inputs (usually the main one) and the output is stdio so mockgen cannot detect the final output package. Setting this flag will then tell mockgen which import to exclude.",
        ),
        "imports": attr.string_dict(
            doc = "Dictionary of name-path pairs of explicit imports to use.",
        ),
        "mock_names": attr.string_dict(
            doc = "Dictionary of interfaceName-mockName pairs of explicit mock names to use. Mock names default to 'Mock'+ interfaceName suffix.",
            default = {},
        ),
        "copyright_file": attr.label(
            doc = "Optional file containing copyright to prepend to the generated contents.",
            allow_single_file = True,
            mandatory = False,
        ),
        "prog_bin": attr.label(
            doc = "The program binary generated by mockgen's -prog_only and compiled by bazel.",
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            mandatory = True,
        ),
        "mockgen_tool": attr.label(
            doc = "The mockgen tool to run",
            default = Label(_MOCKGEN_TOOL),
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            mandatory = False,
        ),
        "_go_context_data": attr.label(
            default = "@io_bazel_rules_go//:go_context_data",
        ),
    },
    toolchains = ["@io_bazel_rules_go//go:toolchain"],
)

def _handle_shared_args(ctx, args):
    needed_files = []

    if ctx.attr.package != "":
        args += ["-package", ctx.attr.package]
    if ctx.attr.self_package != "":
        args += ["-self_package", ctx.attr.self_package]
    if len(ctx.attr.imports) > 0:
        imports = ",".join(["{0}={1}".format(name, pkg) for name, pkg in ctx.attr.imports.items()])
        args += ["-imports", imports]
    if ctx.file.copyright_file != None:
        args += ["-copyright_file", ctx.file.copyright_file.path]
        needed_files.append(ctx.file.copyright_file)
    if len(ctx.attr.mock_names) > 0:
        mock_names = ",".join(["{0}={1}".format(name, pkg) for name, pkg in ctx.attr.mock_names.items()])
        args += ["-mock_names", mock_names]

    return args, needed_files
