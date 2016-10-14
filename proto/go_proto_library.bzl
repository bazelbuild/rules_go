"""A basic go_proto_library.

Takes .proto as srcs and go_proto_library as deps
Note: can also work with a go_library(name=name,...)
      and a filegroup of .protos (name=name+"_protos",...)

A go_proto_library can then be a dependency of go_library or another go_proto_library.

Requires/Uses:
@io_bazel_rules_go for go_* macros/rules.

Does:
Generate protos using the open-source protoc and protoc-gen-go.
Handles transitive dependencies.
gRPC for service generation
Handles bazel-style names like 'foo_proto',
and also Go package-style like 'go_default_library'

Does not yet:
Gets confused if local protos use 'option go_package'

Usage:
In WORKSPACE
load("@io_bazel_rules_go//proto:go_proto_library.bzl", "go_proto_repositories")

go_proto_repositories()

Then in the BUILD file where protos are

load("@io_bazel_rules_go//proto:go_proto_library.bzl", "go_proto_library")

go_proto_library(
  name = "my_proto",
  srcs = ["my.proto"],
  deps = [
    ":other_proto",
    "@com_github_golang_protobuf//ptypes/duration:go_default_library",
  ],
)
"""

load("@io_bazel_rules_go//go:def.bzl", "go_library", "new_go_repository")

_DEFAULT_LIB = "go_default_library"  # matching go_library

_PROTOS_SUFFIX = "_protos"

def _go_prefix(ctx):
  """slash terminated go-prefix."""
  prefix = ctx.attr.go_prefix.go_prefix
  if prefix and not prefix.endswith("/"):
    prefix = prefix + "/"
  return prefix

def _external_dirs(files):
  """Compute any needed -I options to protoc from external filegroups."""
  return set(["/".join(f.dirname.split("/")[:2])
              for f in files if f.dirname[:9] == "external/"])

def _go_proto_library_gen_impl(ctx):
  """Rule implementation that generates Go using protoc."""
  bazel_style = ctx.label.name != _DEFAULT_LIB + _PROTOS_SUFFIX
  protos = list(ctx.files.srcs)
  go_package_name = ""
  if bazel_style:
    go_package_name = "/" + ctx.label.name[:-len(_PROTOS_SUFFIX)]
  m_import_path = ",".join(["M%s=%s%s%s" % (f.path, _go_prefix(ctx),
                                            ctx.label.package, go_package_name)
                            for f in ctx.files.srcs])
  for d in ctx.attr.deps:
    if not hasattr(d, "_protos"):
      # should be a raw filegroup then
      protos += list(d.files)
      continue
    protos += d._protos
    m_import_path += "," + d._m_import_path
  use_grpc = ""
  if ctx.attr.grpc:
    use_grpc = "plugins=grpc,"

  offset = 0
  proto_outs = ctx.outputs.outs
  if bazel_style:
    offset = -1  # extra directory added, need to remove
    proto_outs = [
        ctx.new_file(
            ctx.configuration.bin_dir,
            s.basename[:-len(".proto")] + ".pb.go")
        for s in ctx.files.srcs
    ]
  outdir = "/".join(
      ctx.outputs.outs[0].dirname.split("/")[:offset-len(ctx.label.package.split("/"))])
  ctx.action(
      inputs=protos + ctx.files.protoc_gen_go,
      outputs=proto_outs,
      arguments=["-I.", "--go_out=%s%s:%s" % (
          use_grpc, m_import_path, outdir)] + [
              "-I"+i for i in _external_dirs(protos)
          ] + [
              f.path for f in ctx.files.srcs
          ],
      progress_message="Generating into %s" % ctx.outputs.outs[0].dirname,
      mnemonic="GoProtocGen",
      env = {"PATH": ctx.files.protoc_gen_go[0].dirname},
      executable=ctx.executable.protoc)
  # This is the current hack for files without 'option go_package'
  # Generate into .pb.go, then cp into "real location"
  if bazel_style:
    for proto_out, ctx_out in zip(proto_outs, ctx.outputs.outs):
      ctx.action(
          inputs=[proto_out],
          outputs=[ctx_out],
          command="cp %s %s" % (proto_out.path, ctx_out.path),
          mnemonic="GoProtocGenCp")
  return struct(_protos=protos,
                _m_import_path=m_import_path)

_go_proto_library_gen = rule(
    attrs = {
        "deps": attr.label_list(),
        "srcs": attr.label_list(
            mandatory = True,
            allow_files = True,
        ),
        "grpc": attr.int(default = 0),
        "outs": attr.output_list(mandatory = True),
        "protoc": attr.label(
            default = Label("@com_github_google_protobuf//:protoc"),
            executable = True,
            single_file = True,
            allow_files = True,
            cfg = "host",
        ),
        "protoc_gen_go": attr.label(
            default = Label("@com_github_golang_protobuf//protoc-gen-go"),
            allow_files = True,
            cfg = "host",
        ),
        "_protos": attr.label_list(default = []),
        "go_prefix": attr.label(
            providers = ["go_prefix"],
            default = Label(
                "//:go_prefix",
                relative_to_caller_repository = True,
            ),
            allow_files = False,
            cfg = "host",
        ),
    },
    implementation = _go_proto_library_gen_impl,
)

def _add_target_suffix(target, suffix):
  idx = target.find(":")
  if idx != -1:
    return target + suffix
  toks = target.split("/")
  return target + ":" + toks[-1] + suffix

def go_proto_library(name, srcs = None, deps = None,
                     has_services = 0,
                     testonly = 0, visibility = None,
                     **kwargs):
  """Macro which generates and compiles protobufs for Go.

  Args:
    name: name assigned to the underlying go_library,
          typically "foo_proto" for ["foo.proto"]
    srcs: a list of .proto source files, currently only 1 supported
    deps: a mixed list of either go_proto_libraries, or
          any go_library which has a companion
          filegroup(name=name+"_protos",...)
          which contains the protos which were used
    has_services: indicates the proto has gRPC services and deps
    testonly: mark as testonly
    visibility: visibility to use on underlying go_library
    **kwargs: any other args which are passed through to the underlying go_library
  """
  if not name:
    fail("name is required", "name")
  if not srcs:
    fail("srcs required", "srcs")
  if not deps:
    deps = []
  # bazel-style
  outs = [name + "/" + s[:-len(".proto")] + ".pb.go"
          for s in srcs]
  if name == _DEFAULT_LIB:
    outs = [s[:-len(".proto")] + ".pb.go"
            for s in srcs]

  _go_proto_library_gen(
      name = name + _PROTOS_SUFFIX,
      srcs = srcs,
      deps = [_add_target_suffix(s, _PROTOS_SUFFIX) for s in deps],
      outs = outs,
      testonly = testonly,
      visibility = visibility,
      grpc = has_services,
  )
  grpc_deps = []
  if has_services:
    grpc_deps += [
        "@org_golang_x_net//context:go_default_library",
        "@org_golang_google_grpc//:go_default_library",
    ]
  go_library(
      name = name,
      srcs = [":" + name + _PROTOS_SUFFIX],
      deps = deps + grpc_deps + ["@com_github_golang_protobuf//proto:go_default_library"],
      testonly = testonly,
      visibility = visibility,
      **kwargs
  )

def go_proto_repositories(shared = 1):
  """Add this to your WORKSPACE to pull in all of the needed dependencies."""
  new_go_repository(
      name = "com_github_golang_protobuf",
      importpath = "github.com/golang/protobuf",
      commit = "1f49d83d9aa00e6ce4fc8258c71cc7786aec968a",
  )
  if shared:
    # if using multiple *_proto_library, allows caller to skip this.
    native.git_repository(
        name = "com_github_google_protobuf",
        remote = "https://github.com/google/protobuf",
        commit = "4f032cd9affcff0747f5987dfdc0a04deee7a46b",
    )

  # Needed for gRPC, only loaded by bazel if used
  new_go_repository(
      name = "org_golang_x_net",
      commit = "de35ec43e7a9aabd6a9c54d2898220ea7e44de7d",
      importpath = "golang.org/x/net",
  )
  new_go_repository(
      name = "org_golang_google_grpc",
      tag = "v1.0.1-GA",
      importpath = "google.golang.org/grpc",
  )
