load("//go:def.bzl", "GoArchive", "GoLibrary", "GoSource")
load("//proto:def.bzl", "go_proto_library")
load("//proto:compiler.bzl", "GoProtoCompiler")

_proto_library_suffix = "proto"
_go_proto_library_suffix = "go_proto"

# TODO: this should be private. Make sure nothing depends on it, then rename it.
WELL_KNOWN_TYPE_PACKAGES = {
    "any": ("github.com/golang/protobuf/ptypes/any", []),
    "api": ("google.golang.org/genproto/protobuf/api", ["source_context", "type"]),
    "compiler_plugin": ("github.com/golang/protobuf/protoc-gen-go/plugin", ["descriptor"]),
    "descriptor": ("github.com/golang/protobuf/protoc-gen-go/descriptor", []),
    "duration": ("github.com/golang/protobuf/ptypes/duration", []),
    "empty": ("github.com/golang/protobuf/ptypes/empty", []),
    "field_mask": ("google.golang.org/genproto/protobuf/field_mask", []),
    "source_context": ("google.golang.org/genproto/protobuf/source_context", []),
    "struct": ("github.com/golang/protobuf/ptypes/struct", []),
    "timestamp": ("github.com/golang/protobuf/ptypes/timestamp", []),
    "type": ("google.golang.org/genproto/protobuf/ptype", ["any", "source_context"]),
    "wrappers": ("github.com/golang/protobuf/ptypes/wrappers", []),
}

GOGO_WELL_KNOWN_TYPE_REMAPS = [
    "Mgoogle/protobuf/{}.proto=github.com/gogo/protobuf/types".format(wkt)
    for wkt, (go_package, _) in WELL_KNOWN_TYPE_PACKAGES.items()
    if "protoc-gen-go" not in go_package
] + [
    "Mgoogle/protobuf/descriptor.proto=github.com/gogo/protobuf/protoc-gen-gogo/descriptor",
    "Mgoogle/protobuf/compiler_plugin.proto=github.com/gogo/protobuf/protoc-gen-gogo/plugin",
]

WELL_KNOWN_TYPE_RULES = {
    wkt: "@io_bazel_rules_go//proto/wkt:{}_{}".format(wkt, _go_proto_library_suffix)
    for wkt in WELL_KNOWN_TYPE_PACKAGES.keys()
}

PROTO_RUNTIME_DEPS = [
    "@com_github_golang_protobuf//proto:go_default_library",
    "@org_golang_google_protobuf//reflect/protoreflect:go_default_library",
    "@org_golang_google_protobuf//runtime/protoiface:go_default_library",
    "@org_golang_google_protobuf//runtime/protoimpl:go_default_library",
]

def gen_well_known_types():
    for wkt, rule in WELL_KNOWN_TYPE_RULES.items():
        (go_package, deps) = WELL_KNOWN_TYPE_PACKAGES[wkt]
        go_proto_library(
            name = rule.rsplit(":", 1)[1],
            compilers = ["@io_bazel_rules_go//proto:go_proto_bootstrap"],
            importpath = go_package,
            proto = "@com_google_protobuf//:{}_{}".format(wkt, _proto_library_suffix),
            visibility = ["//visibility:public"],
            deps = [WELL_KNOWN_TYPE_RULES[dep] for dep in deps],
        )

def _go_proto_wrapper_compile(go, compiler, protos, imports, importpath):
    return []

def _go_proto_wrapper_impl(ctx):
    return [
        ctx.attr.library[GoLibrary],
        ctx.attr.library[GoSource],
        GoProtoCompiler(
            deps = ctx.attr._deps,
            compile = _go_proto_wrapper_compile,
            valid_archive = True,
        ),
    ]

go_proto_wrapper = rule(
    implementation = _go_proto_wrapper_impl,
    attrs = {
        "library": attr.label(
            mandatory = True,
            providers = [GoLibrary, GoSource],
        ),
        "_deps": attr.label_list(
            default = PROTO_RUNTIME_DEPS,
            providers = [GoLibrary, GoSource, GoArchive],
        ),
    },
)
