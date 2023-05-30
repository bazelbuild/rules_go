load("//go/private:sdk.bzl", "detect_host_platform", "go_download_sdk_rule", "go_host_sdk_rule", "go_multiple_toolchains")
load("//go/private:repositories.bzl", "go_rules_dependencies")

def host_compatible_toolchain_impl(ctx):
    ctx.file("BUILD.bazel", content = "")
    load_statements = []
    sdk_labels = []
    for i, toolchain in enumerate(ctx.attr.toolchains):
        if toolchain.endswith(".bzl"):
            # bzl file passed via the `custom` tag, with a variable containing the toolchain label.
            # This indirection enables the user to generate the file differently depending on the environment.
            # In particular the toolchain variable can be equal to None in which case it will be ignored.
            label = "toolchain_{}".format(i)
            load_statements.append(
                """load("{custom_toolchain}", {label} = "toolchain")""".format(
                    custom_toolchain = toolchain,
                    label = label,
                ),
            )
        else:
            label = """Label("{}")""".format(toolchain)
        sdk_labels.append(label)
    ctx.file("defs.bzl", content = """
{load_statements}
host_compatible_sdk = {host_compatible_sdk}
""".format(
        load_statements = "\n".join(load_statements),
        host_compatible_sdk = " or ".join(sdk_labels),
    ))

host_compatible_toolchain = repository_rule(
    implementation = host_compatible_toolchain_impl,
    attrs = {
        "toolchains": attr.string_list(
            doc = "A non empty list of host compatible toolchains",
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
        "urls": attr.string_list(default = ["https://dl.google.com/go/{}"]),
        "version": attr.string(),
        "strip_prefix": attr.string(default = "go"),
    },
)

_host_tag = tag_class(
    attrs = {
        "name": attr.string(),
        "version": attr.string(),
    },
)

_custom_tag = tag_class(
    doc = "Declare a custom toolchain to rules_go. It will then be considered when choosing the toolchain exposed by the `host_compatible_sdk` repository",
    attrs = {
        "custom_toolchain_bzl_file": attr.label(
            doc = """A bazel file with a `toolchain` variable, containing the label of the `ROOT` file of a go sdk.
This indirection enables the user to generate the file differently depending on the environment.
In particular the toolchain variable can be equal to None in which case this custom toolchain will be ignored.
""",
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

    # We build a list of the host compatible toolchains declared by the download, host and custom tags.
    # The order follows bazel's iteration over modules (the toolchains declared by the root module are at the beginning of the list).
    # If a module declares multiple toolchains, custom ones appear first, then the downloaded ones, then the host one.
    # This list will contain at least `go_default_sdk` which is declared by the `rules_go` module itself.
    host_compatible_toolchains = []
    host_detected_goos, host_detected_goarch = detect_host_platform(ctx)
    toolchains = []
    for module in ctx.modules:
        for index, custom_tag in enumerate(module.tags.custom):
            # Custom toolchains should contain a `toolchain` variable equal to None unless compatible with the host.
            host_compatible_toolchains.append(str(custom_tag.custom_toolchain_bzl_file))

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
                urls = download_tag.urls,
                version = download_tag.version,
            )

            if (not download_tag.goos or download_tag.goos == host_detected_goos) and (not download_tag.goarch or download_tag.goarch == host_detected_goarch):
                host_compatible_toolchains.append("@{}//:ROOT".format(name))

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
            )

            toolchains.append(struct(
                goos = "",
                goarch = "",
                sdk_repo = name,
                sdk_type = "host",
                sdk_version = host_tag.version,
            ))
            host_compatible_toolchains.append("@{}//:ROOT".format(name))

    host_compatible_toolchain(name = "go_host_compatible_sdk", toolchains = host_compatible_toolchains)
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
        name = module.name,
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
        "custom": _custom_tag,
    },
)

def _non_module_dependencies_impl(_ctx):
    go_rules_dependencies(force = True)

non_module_dependencies = module_extension(
    implementation = _non_module_dependencies_impl,
)
