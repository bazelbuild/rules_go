PROTO_RUNTIME_DEPS = [
    "@com_github_golang_protobuf//proto:go_default_library",
    "@org_golang_google_protobuf//proto:go_default_library",
    "@org_golang_google_protobuf//reflect/protoreflect:go_default_library",
    "@org_golang_google_protobuf//reflect/protoregistry:go_default_library",
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
