load("//go/private:sdk.bzl", "detect_host_platform", "go_download_sdk_rule", "go_host_sdk_rule", "go_multiple_toolchains")
load("//go/private:repositories.bzl", "go_rules_dependencies")

def host_compatible_toolchain_impl(ctx):
    ctx.file("BUILD.bazel")
    ctx.file("defs.bzl", content = """
HOST_COMPATIBLE_SDK = Label({})
""".format(repr(ctx.attr.toolchain)))

host_compatible_toolchain = repository_rule(
    implementation = host_compatible_toolchain_impl,
    attrs = {
        # We cannot use attr.label for the `toolchain` attribute since the module extension cannot
        # refer to the repositories it creates by their apparent repository names.
        "toolchain": attr.string(
            doc = "The apparent label of a `ROOT` file in the repository of a host compatible toolchain created by the `go_sdk` extension",
            mandatory = True,
        ),
    },
    doc = "An external repository to expose the first host compatible toolchain",
)

_download_tag = tag_class(
    attrs = {
        "name": attr.string(),
        "goos": attr.string(),
        "goarch": attr.string(),
        "sdks": attr.string_list_dict(),
        "experiments": attr.string_list(
            doc = "Go experiments to enable via GOEXPERIMENT",
        ),
        "urls": attr.string_list(default = ["https://dl.google.com/go/{}"]),
        "version": attr.string(),
        "strip_prefix": attr.string(default = "go"),
    },
)

_host_tag = tag_class(
    attrs = {
        "name": attr.string(),
        "version": attr.string(),
        "experiments": attr.string_list(
            doc = "Go experiments to enable via GOEXPERIMENT",
        ),
    },
)

# This limit can be increased essentially arbitrarily, but doing so will cause a rebuild of all
# targets using any of these toolchains due to the changed repository name.
_MAX_NUM_TOOLCHAINS = 9999
_TOOLCHAIN_INDEX_PAD_LENGTH = len(str(_MAX_NUM_TOOLCHAINS))

def _go_sdk_impl(ctx):
    multi_version_module = {}
    for module in ctx.modules:
        if module.name in multi_version_module:
            multi_version_module[module.name] = True
        else:
            multi_version_module[module.name] = False

    # We remember the first host compatible toolchain declared by the download and host tags.
    # The order follows bazel's iteration over modules (the toolchains declared by the root module are considered first).
    # We know that at least `go_default_sdk` (which is declared by the `rules_go` module itself) is host compatible.
    first_host_compatible_toolchain = None
    host_detected_goos, host_detected_goarch = detect_host_platform(ctx)
    toolchains = []
    for module in ctx.modules:
        for index, download_tag in enumerate(module.tags.download):
            # SDKs without an explicit version are fetched even when not selected by toolchain
            # resolution. This is acceptable if brought in by the root module, but transitive
            # dependencies should not slow down the build in this way.
            if not module.is_root and not download_tag.version:
                fail("go_sdk.download: version must be specified in non-root module " + module.name)

            # SDKs with an explicit name are at risk of colliding with those from other modules.
            # This is acceptable if brought in by the root module as the user is responsible for any
            # conflicts that arise. rules_go itself provides "go_default_sdk", which is used by
            # Gazelle to bootstrap itself.
            # TODO(https://github.com/bazelbuild/bazel-gazelle/issues/1469): Investigate whether
            #  Gazelle can use the first user-defined SDK instead to prevent unnecessary downloads.
            if (not module.is_root and not module.name == "rules_go") and download_tag.name:
                fail("go_sdk.download: name must not be specified in non-root module " + module.name)

            name = download_tag.name or _default_go_sdk_name(
                module = module,
                multi_version = multi_version_module[module.name],
                tag_type = "download",
                index = index,
            )
            go_download_sdk_rule(
                name = name,
                goos = download_tag.goos,
                goarch = download_tag.goarch,
                sdks = download_tag.sdks,
                experiments = download_tag.experiments,
                urls = download_tag.urls,
                version = download_tag.version,
                strip_prefix = download_tag.strip_prefix,
            )

            if (not download_tag.goos or download_tag.goos == host_detected_goos) and (not download_tag.goarch or download_tag.goarch == host_detected_goarch):
                first_host_compatible_toolchain = first_host_compatible_toolchain or "@{}//:ROOT".format(name)

            toolchains.append(struct(
                goos = download_tag.goos,
                goarch = download_tag.goarch,
                sdk_repo = name,
                sdk_type = "remote",
                sdk_version = download_tag.version,
            ))

        for index, host_tag in enumerate(module.tags.host):
            # Dependencies can rely on rules_go providing a default remote SDK. They can also
            # configure a specific version of the SDK to use. However, they should not add a
            # dependency on the host's Go SDK.
            if not module.is_root:
                fail("go_sdk.host: cannot be used in non-root module " + module.name)

            name = host_tag.name or _default_go_sdk_name(
                module = module,
                multi_version = multi_version_module[module.name],
                tag_type = "host",
                index = index,
            )
            go_host_sdk_rule(
                name = name,
                version = host_tag.version,
                experiments = host_tag.experiments,
            )

            toolchains.append(struct(
                goos = "",
                goarch = "",
                sdk_repo = name,
                sdk_type = "host",
                sdk_version = host_tag.version,
            ))
            first_host_compatible_toolchain = first_host_compatible_toolchain or "@{}//:ROOT".format(name)

    host_compatible_toolchain(name = "go_host_compatible_sdk_label", toolchain = first_host_compatible_toolchain)
    if len(toolchains) > _MAX_NUM_TOOLCHAINS:
        fail("more than {} go_sdk tags are not supported".format(_MAX_NUM_TOOLCHAINS))

    # Toolchains in a BUILD file are registered in the order given by name, not in the order they
    # are declared:
    # https://cs.opensource.google/bazel/bazel/+/master:src/main/java/com/google/devtools/build/lib/packages/Package.java;drc=8e41dce65b97a3d466d6b1e65005abc52a07b90b;l=156
    # We pad with an index that lexicographically sorts in the same order as if these toolchains
    # were registered using register_toolchains in their MODULE.bazel files.
    go_multiple_toolchains(
        name = "go_toolchains",
        prefixes = [
            _toolchain_prefix(index, toolchain.sdk_repo)
            for index, toolchain in enumerate(toolchains)
        ],
        geese = [toolchain.goos for toolchain in toolchains],
        goarchs = [toolchain.goarch for toolchain in toolchains],
        sdk_repos = [toolchain.sdk_repo for toolchain in toolchains],
        sdk_types = [toolchain.sdk_type for toolchain in toolchains],
        sdk_versions = [toolchain.sdk_version for toolchain in toolchains],
    )

def _default_go_sdk_name(*, module, multi_version, tag_type, index):
    # Keep the version out of the repository name if possible to prevent unnecessary rebuilds when
    # it changes.
    return "{name}_{version}_{tag_type}_{index}".format(
        # "main_" is not a valid module name and thus can't collide.
        name = module.name or "main_",
        version = module.version if multi_version else "",
        tag_type = tag_type,
        index = index,
    )

def _toolchain_prefix(index, name):
    """Prefixes the given name with the index, padded with zeros to ensure lexicographic sorting.

    Examples:
      _toolchain_prefix(   2, "foo") == "_0002_foo_"
      _toolchain_prefix(2000, "foo") == "_2000_foo_"
    """
    return "_{}_{}_".format(_left_pad_zero(index, _TOOLCHAIN_INDEX_PAD_LENGTH), name)

def _left_pad_zero(index, length):
    if index < 0:
        fail("index must be non-negative")
    return ("0" * length + str(index))[-length:]

go_sdk = module_extension(
    implementation = _go_sdk_impl,
    tag_classes = {
        "download": _download_tag,
        "host": _host_tag,
    },
)

def _non_module_dependencies_impl(_ctx):
    go_rules_dependencies(force = True)

non_module_dependencies = module_extension(
    implementation = _non_module_dependencies_impl,
)
