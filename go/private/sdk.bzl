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

load(
    "//go/private:common.bzl",
    "executable_path",
)
load(
    "//go/private:nogo.bzl",
    "go_register_nogo",
)
load(
    "//go/private:platforms.bzl",
    "generate_toolchain_names",
)
load(
    "//go/private/skylib/lib:versions.bzl",
    "versions",
)

MIN_SUPPORTED_VERSION = "1.13"

def _go_host_sdk_impl(ctx):
    goroot = _detect_host_sdk(ctx)
    platform = _detect_sdk_platform(ctx, goroot)
    _sdk_build_file(ctx, platform)
    _local_sdk(ctx, goroot)

_go_host_sdk = repository_rule(
    implementation = _go_host_sdk_impl,
    environ = ["GOROOT"],
)

def go_host_sdk(name, **kwargs):
    _go_host_sdk(name = name, **kwargs)
    _register_toolchains(name)

def _go_download_sdk_impl(ctx):
    if not ctx.attr.goos and not ctx.attr.goarch:
        goos, goarch = _detect_host_platform(ctx)
    else:
        if not ctx.attr.goos:
            fail("goarch set but goos not set")
        if not ctx.attr.goarch:
            fail("goos set but goarch not set")
        goos, goarch = ctx.attr.goos, ctx.attr.goarch
    platform = goos + "_" + goarch
    _sdk_build_file(ctx, platform)

    version = ctx.attr.version
    sdks = ctx.attr.sdks

    if not sdks:
        # If sdks was unspecified, download a full list of files.
        # If version was unspecified, pick the latest version.
        # Even if version was specified, we need to download the file list
        # to find the SHA-256 sum. If we don't have it, Bazel won't cache
        # the downloaded archive.
        if not version:
            ctx.report_progress("Finding latest Go version")
        else:
            ctx.report_progress("Finding Go SHA-256 sums")
        ctx.download(
            url = [
                "https://golang.org/dl/?mode=json&include=all",
                "https://golang.google.cn/dl/?mode=json&include=all",
            ],
            output = "versions.json",
        )

        data = ctx.read("versions.json")
        sdks_by_version = _parse_versions_json(data)

        if not version:
            highest_version = None
            for v in sdks_by_version.keys():
                sv = versions.parse(v)
                if v != ".".join([str(d) for d in sv]):
                    # skip pre-release versions
                    continue
                if not highest_version or sv > highest_version:
                    highest_version = sv
            if not highest_version:
                fail("did not find any Go versions in https://golang.org/dl/?mode=json")
            version = ".".join([str(d) for d in highest_version])
        sdks = sdks_by_version[version]

    if platform not in sdks:
        fail("unsupported platform {}".format(platform))
    filename, sha256 = sdks[platform]
    _remote_sdk(ctx, [url.format(filename) for url in ctx.attr.urls], ctx.attr.strip_prefix, sha256)

    if not ctx.attr.sdks and not ctx.attr.version:
        # Returning this makes Bazel print a message that 'version' must be
        # specified for a reproducible build.
        return {
            "name": ctx.attr.name,
            "goos": ctx.attr.goos,
            "goarch": ctx.attr.goarch,
            "sdks": ctx.attr.sdks,
            "urls": ctx.attr.urls,
            "version": version,
            "strip_prefix": ctx.attr.strip_prefix,
        }
    return None

_go_download_sdk = repository_rule(
    implementation = _go_download_sdk_impl,
    attrs = {
        "goos": attr.string(),
        "goarch": attr.string(),
        "sdks": attr.string_list_dict(),
        "urls": attr.string_list(default = ["https://dl.google.com/go/{}"]),
        "version": attr.string(),
        "strip_prefix": attr.string(default = "go"),
    },
)

def go_download_sdk(name, **kwargs):
    _go_download_sdk(name = name, **kwargs)
    _register_toolchains(name)

def _go_local_sdk_impl(ctx):
    goroot = ctx.attr.path
    platform = _detect_sdk_platform(ctx, goroot)
    _sdk_build_file(ctx, platform)
    _local_sdk(ctx, goroot)

_go_local_sdk = repository_rule(
    implementation = _go_local_sdk_impl,
    attrs = {
        "path": attr.string(),
    },
)

def go_local_sdk(name, **kwargs):
    _go_local_sdk(name = name, **kwargs)
    _register_toolchains(name)

def _go_wrap_sdk_impl(ctx):
    goroot = str(ctx.path(ctx.attr.root_file).dirname)
    platform = _detect_sdk_platform(ctx, goroot)
    _sdk_build_file(ctx, platform)
    _local_sdk(ctx, goroot)

_go_wrap_sdk = repository_rule(
    implementation = _go_wrap_sdk_impl,
    attrs = {
        "root_file": attr.label(
            mandatory = True,
            doc = "A file in the SDK root direcotry. Used to determine GOROOT.",
        ),
    },
)

def go_wrap_sdk(name, **kwargs):
    _go_wrap_sdk(name = name, **kwargs)
    _register_toolchains(name)

def _register_toolchains(repo):
    labels = [
        "@{}//:{}".format(repo, name)
        for name in generate_toolchain_names()
    ]
    native.register_toolchains(*labels)

def _remote_sdk(ctx, urls, strip_prefix, sha256):
    if len(urls) == 0:
        fail("no urls specified")
    ctx.report_progress("Downloading and extracting Go toolchain")
    ctx.download_and_extract(
        url = urls,
        stripPrefix = strip_prefix,
        sha256 = sha256,
    )

def _local_sdk(ctx, path):
    for entry in ["src", "pkg", "bin"]:
        ctx.symlink(path + "/" + entry, entry)

def _sdk_build_file(ctx, platform):
    ctx.file("ROOT")
    goos, _, goarch = platform.partition("_")
    ctx.template(
        "BUILD.bazel",
        Label("@io_bazel_rules_go//go/private:BUILD.sdk.bazel"),
        executable = False,
        substitutions = {
            "{goos}": goos,
            "{goarch}": goarch,
            "{exe}": ".exe" if goos == "windows" else "",
        },
    )

def _detect_host_platform(ctx):
    if ctx.os.name == "linux":
        goos, goarch = "linux", "amd64"
        res = ctx.execute(["uname", "-p"])
        if res.return_code == 0:
            uname = res.stdout.strip()
            if uname == "s390x":
                goarch = "s390x"
            elif uname == "i686":
                goarch = "386"

        # uname -p is not working on Aarch64 boards
        # or for ppc64le on some distros
        res = ctx.execute(["uname", "-m"])
        if res.return_code == 0:
            uname = res.stdout.strip()
            if uname == "aarch64":
                goarch = "arm64"
            elif uname == "armv6l":
                goarch = "arm"
            elif uname == "armv7l":
                goarch = "arm"
            elif uname == "ppc64le":
                goarch = "ppc64le"

        # Default to amd64 when uname doesn't return a known value.

    elif ctx.os.name == "mac os x":
        goos, goarch = "darwin", "amd64"
    elif ctx.os.name.startswith("windows"):
        goos, goarch = "windows", "amd64"
    elif ctx.os.name == "freebsd":
        goos, goarch = "freebsd", "amd64"
    else:
        fail("Unsupported operating system: " + ctx.os.name)

    return goos, goarch

def _detect_host_sdk(ctx):
    root = "@invalid@"
    if "GOROOT" in ctx.os.environ:
        return ctx.os.environ["GOROOT"]
    res = ctx.execute([executable_path(ctx, "go"), "env", "GOROOT"])
    if res.return_code:
        fail("Could not detect host go version")
    root = res.stdout.strip()
    if not root:
        fail("host go version failed to report it's GOROOT")
    return root

def _detect_sdk_platform(ctx, goroot):
    res = ctx.execute(["ls", goroot + "/pkg/tool"])
    if res.return_code != 0:
        fail("Could not detect SDK platform")
    for f in res.stdout.strip().split("\n"):
        if f.find("_") >= 0:
            return f
    fail("Could not detect SDK platform")

def _parse_versions_json(data):
    """Parses version metadata returned by golang.org.

    This is a really basic JSON parser. We can only do so much in Starlark
    without recursion. We don't want to download a platform-specific binary
    for this, and we can't rely on any particular scripting language being
    installed.

    Args:
        data: the contents of the file downloaded from
            https://golang.org/dl/?mode=json. We assume the file is valid
            JSON, is spaced and indented, and is in a particular format.

    Return:
        A dict mapping version strings (like "1.15.5") to dicts mapping
        platform names (like "linux_amd64") to pairs of filenames
        (like "go1.15.5.linux-amd64.tar.gz") and hex-encoded SHA-256 sums.
    """
    sdks_by_version = {}

    START_STATE = 0
    VERSION_STATE = 1
    FILE_STATE = 2
    state = START_STATE

    version = None
    version_files = None
    file_fields = None

    for i, line in enumerate(data.split("\n")):
        line = line.strip()
        if not line:
            continue
        if state == START_STATE:
            if line == "{":
                version_files = {}
                state = VERSION_STATE
        elif state == VERSION_STATE:
            key, value = _parse_versions_json_field(line)
            if key == "version":
                version = value
            elif line == "{":
                state = FILE_STATE
                file_fields = {}
            elif line in ("}", "},"):
                if version and version.startswith("go") and version_files:
                    sdks_by_version[version[len("go"):]] = version_files
                version = None
                version_files = None
                state = START_STATE
        elif state == FILE_STATE:
            key, value = _parse_versions_json_field(line)
            if key != "":
                file_fields[key] = value
            elif line in ("}", "},"):
                if (all([f in file_fields for f in ("filename", "os", "arch", "sha256", "kind")]) and
                    file_fields["kind"] == "archive"):
                    goos_goarch = file_fields["os"] + "_" + file_fields["arch"]
                    version_files[goos_goarch] = (file_fields["filename"], file_fields["sha256"])
                file_fields = None
                state = VERSION_STATE

    return sdks_by_version

def _parse_versions_json_field(line):
    """Parses a line like '"key": "value",' into a key and value pair."""
    if line.endswith(","):
        line = line[:-1]
    k, sep, v = line.partition('": "')
    if not sep or not k.startswith('"') or not v.endswith('"'):
        return "", ""
    return k[1:], v[:-1]

def go_register_toolchains(version = None, nogo = None, go_version = None):
    """See /go/toolchains.rst#go-register-toolchains for full documentation."""
    if not version:
        version = go_version  # old name

    sdk_kinds = ("_go_download_sdk", "_go_host_sdk", "_go_local_sdk", "_go_wrap_sdk")
    existing_rules = native.existing_rules()
    sdk_rules = [r for r in existing_rules.values() if r["kind"] in sdk_kinds]
    if len(sdk_rules) == 0 and "go_sdk" in existing_rules:
        # may be local_repository in bazel_tests.
        sdk_rules.append(existing_rules["go_sdk"])

    if version and len(sdk_rules) > 0:
        fail("go_register_toolchains: version set after go sdk rule declared ({})".format(", ".join([r["name"] for r in sdk_rules])))
    if len(sdk_rules) == 0:
        if not version:
            fail('go_register_toolchains: version must be set to a string like "1.15.5" or "host"')
        elif version == "host":
            go_host_sdk(name = "go_sdk")
        else:
            if not versions.is_at_least(MIN_SUPPORTED_VERSION, version):
                print("DEPRECATED: Go versions before {} are not supported and may not work".format(MIN_SUPPORTED_VERSION))
            go_download_sdk(
                name = "go_sdk",
                version = version,
            )

    if nogo:
        # Override default definition in go_rules_dependencies().
        go_register_nogo(
            name = "io_bazel_rules_nogo",
            nogo = nogo,
        )
