load("//go:def.bzl", "GoArchive", "GoLibrary", "GoSource")
load("//proto:compiler.bzl", "GoProtoCompiler")

_go_proto_library_suffix = "go_proto"

# NOTE: since protobuf 3.14, the WKTs no longer use these paths. They're only
# used by gogo below. Not clear if that actually works or if we should
# continue supporting gogo.
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

# NOTE: only used by gogo.
WELL_KNOWN_TYPE_RULES = {
    wkt: Label("//proto/wkt:{}_{}".format(wkt, _go_proto_library_suffix))
    for wkt in WELL_KNOWN_TYPE_PACKAGES.keys()
}

PROTO_RUNTIME_DEPS = [
    "@com_github_golang_protobuf//proto:go_default_library",
    "@org_golang_google_protobuf//proto:go_default_library",
    "@org_golang_google_protobuf//reflect/protoreflect:go_default_library",
    "@org_golang_google_protobuf//runtime/protoiface:go_default_library",
    "@org_golang_google_protobuf//runtime/protoimpl:go_default_library",
]

# In protobuf 3.14, the 'option go_package' declarations were changed in the
# Well Known Types to point to the APIv2 packages below. Consequently, generated
# proto code will import APIv2 packages instead of the APIv1 packages, even
# when the APIv1 compiler is used (which is still the default).
#
# protobuf 3.14 is now the minimum supported version, so we no longer depend
# on the APIv1 packages.
WELL_KNOWN_TYPES_APIV2 = [
    "@org_golang_google_protobuf//types/descriptorpb",
    "@org_golang_google_protobuf//types/known/anypb",
    "@org_golang_google_protobuf//types/known/apipb",
    "@org_golang_google_protobuf//types/known/durationpb",
    "@org_golang_google_protobuf//types/known/emptypb",
    "@org_golang_google_protobuf//types/known/fieldmaskpb",
    "@org_golang_google_protobuf//types/known/sourcecontextpb",
    "@org_golang_google_protobuf//types/known/structpb",
    "@org_golang_google_protobuf//types/known/timestamppb",
    "@org_golang_google_protobuf//types/known/typepb",
    "@org_golang_google_protobuf//types/known/wrapperspb",
    "@org_golang_google_protobuf//types/pluginpb",
]

# buildifier: disable=unused-variable
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
