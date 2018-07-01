load(
    "@io_bazel_rules_go//go/private:context.bzl",
    "go_context",
)
load(
    "@io_bazel_rules_go//go/private:common.bzl",
    "env_execute",
)
load(
    "@io_bazel_rules_go//go/private:rules/rule.bzl",
    "go_rule",
)
load(
    "@io_bazel_rules_go//go/private:skylib/lib/paths.bzl",
    "paths",
)
load(
    "@io_bazel_rules_go//go/private:skylib/lib/shell.bzl",
    "shell",
)

# _bazelrc is the bazel.rc file that sets the default options for tests
def _bazelrc(strategy):
    return """
build --verbose_failures
build --sandbox_debug
build --test_output=errors
build --spawn_strategy={strategy}
build --genrule_strategy={strategy}

test --test_strategy={strategy}
test --nocache_test_results

build:isolate --
build:fetch --fetch=True
""".format(strategy = strategy)

# _basic_workspace is the content appended to all test workspace files
# it contains the calls required to make the go rules work
_basic_workspace = """
load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependencies", "go_register_toolchains")
go_rules_dependencies()
"""

# _bazel_test_script_template is the template for the bazel invocation script
_bazel_test_script_template = """
set -u

echo running in {work_dir}
unset TEST_TMPDIR
RULES_GO_OUTPUT={output}

mkdir -p {work_dir}
mkdir -p {cache_dir}
cp -f {workspace} {work_dir}/WORKSPACE
cp -f {build} {work_dir}/BUILD.bazel
extra_files=({extra_files})
if [ "${{#extra_files[@]}}" -ne 0 ]; then
  cp -f "${{extra_files[@]}}" {work_dir}/
fi
cd {work_dir}

output_base_arg=""
if (( {clean_build} )); then
  tmp_output_base="$(mktemp -d)"
  output_base_arg="--output_base=${{tmp_output_base}}"
fi

cmd=(
{bazel} --bazelrc {bazelrc} ${{output_base_arg}} {command}
--experimental_repository_cache={cache_dir} --config {config} {args}
{target}
)
echo "${{cmd[*]}}" >bazel-output.txt
"${{cmd[@]}}" >>bazel-output.txt 2>&1
result=$?

function at_exit {{
  echo "bazel exited with status $result"
  echo "----- bazel-output.txt begin -----"
  cat bazel-output.txt
  echo "----- bazel-output.txt end -----"
  for log in {logs}; do
    if [ ! -e "$log" ]; then
      echo "----- $log not found -----"
    else
      echo "----- $log begin -----"
      cat "$log"
      echo "----- $log end -----"
    fi
  done
  if (( {clean_build} )); then
    {bazel} --bazelrc {bazelrc} ${{output_base_arg}} clean &> /dev/null
    {bazel} --bazelrc {bazelrc} ${{output_base_arg}} shutdown &> /dev/null
  fi
}}
trap at_exit EXIT

{check}

exit $result
"""

# _env_build_template is the template for the bazel test environment repository build file
_env_build_template = """
load("@io_bazel_rules_go//tests:bazel_tests.bzl", "bazel_test_settings")
bazel_test_settings(
  name = "settings",
  bazel = "{bazel}",
  exec_root = "{exec_root}",
  scratch_dir = "{scratch_dir}",
  visibility = ["//visibility:public"],
)
filegroup(
  name = "standalone_bazelrc",
  srcs = ["test.bazelrc"],
  visibility = ["//visibility:public"],
)
filegroup(
  name = "sandboxed_bazelrc",
  srcs = ["sandboxed_test.bazelrc"],
  visibility = ["//visibility:public"],
)
"""

CURRENT_VERSION = "current"

def _bazel_test_script_impl(ctx):
    go = go_context(ctx)
    script_file = go.declare_file(go, ext = ".bash")

    if not ctx.attr.targets:
        # Skip test when there are no targets. Targets may be platform-specific,
        # and we may not have any targets on some platforms.
        ctx.actions.write(script_file, "", is_executable = True)
        return [DefaultInfo(files = depset([script_file]))]

    if ctx.attr.go_version == CURRENT_VERSION:
        register = "go_register_toolchains()\n"
    elif ctx.attr.go_version != None:
        register = 'go_register_toolchains(go_version="{}")\n'.format(ctx.attr.go_version)

    workspace_content = 'workspace(name = "bazel_test")\n\n'
    for ext in ctx.attr.externals:
        root = ext.label.workspace_root
        _, _, name = ext.label.workspace_root.rpartition("/")
        workspace_content += 'local_repository(name="{name}", path="{exec_root}/{root}")\n'.format(
            name = name,
            root = root,
            exec_root = ctx.attr._settings.exec_root,
        )
    if ctx.attr.workspace:
        workspace_content += ctx.attr.workspace
    else:
        workspace_content += _basic_workspace.format()
        workspace_content += register

    workspace_file = go.declare_file(go, path = "WORKSPACE.in")
    ctx.actions.write(workspace_file, workspace_content)
    build_file = go.declare_file(go, path = "BUILD.in")
    ctx.actions.write(build_file, ctx.attr.build)

    output = "external/" + ctx.workspace_name + "/" + ctx.label.package
    targets = ["@" + ctx.workspace_name + "//" + ctx.label.package + t if t.startswith(":") else t for t in ctx.attr.targets]
    logs = []
    if ctx.attr.command in ("test", "coverage"):
        # TODO(jayconrod): read logs for other packages
        logs = [
            "bazel-testlogs/{}/{}/test.log".format(output, t[1:])
            for t in ctx.attr.targets
            if t.startswith(":")
        ]

    script_content = _bazel_test_script_template.format(
        bazelrc = shell.quote(ctx.attr._settings.exec_root + "/" + ctx.file.bazelrc.path),
        config = ctx.attr.config,
        extra_files = " ".join([shell.quote(paths.join(ctx.attr._settings.exec_root, "execroot", "io_bazel_rules_go", file.path)) for file in ctx.files.extra_files]),
        command = ctx.attr.command,
        args = " ".join(ctx.attr.args),
        target = " ".join(targets),
        logs = " ".join([shell.quote(l) for l in logs]),
        check = ctx.attr.check,
        workspace = shell.quote(workspace_file.short_path),
        build = shell.quote(build_file.short_path),
        output = shell.quote(output),
        bazel = ctx.attr._settings.bazel,
        work_dir = shell.quote(ctx.attr._settings.scratch_dir + "/" + ctx.attr.config),
        cache_dir = shell.quote(ctx.attr._settings.scratch_dir + "/cache"),
        clean_build = "1" if ctx.attr.clean_build else "0",
    )
    ctx.actions.write(output = script_file, is_executable = True, content = script_content)
    return struct(
        files = depset([script_file]),
        runfiles = ctx.runfiles(
            [workspace_file, build_file] + ctx.files.extra_files,
            collect_data = True,
        ),
    )

_bazel_test_script = go_rule(
    _bazel_test_script_impl,
    attrs = {
        "command": attr.string(
            mandatory = True,
            values = [
                "build",
                "test",
                "coverage",
                "run",
            ],
        ),
        "args": attr.string_list(default = []),
        "targets": attr.string_list(mandatory = True),
        "externals": attr.label_list(allow_files = True),
        "go_version": attr.string(default = CURRENT_VERSION),
        "workspace": attr.string(),
        "build": attr.string(),
        "check": attr.string(),
        "config": attr.string(default = "isolate"),
        "extra_files": attr.label_list(allow_files = True),
        "data": attr.label_list(
            allow_files = True,
            cfg = "data",
        ),
        "clean_build": attr.bool(default = False),
        "bazelrc": attr.label(
            allow_files = True,
            single_file = True,
            default = "@bazel_test//:standalone_bazelrc",
        ),
        "_settings": attr.label(default = Label("@bazel_test//:settings")),
    },
)

def bazel_test(name, command = None, args = None, targets = None, go_version = None, tags = [], externals = [], workspace = "", build = "", check = "", config = None, extra_files = [], standalone = True, clean_build = False):
    script_name = name + "_script"
    externals = externals + [
        "@io_bazel_rules_go//:AUTHORS",
    ]
    if go_version == None or go_version == CURRENT_VERSION:
        externals.append("@go_sdk//:packages.txt")

    bazelrc = "@bazel_test//:standalone_bazelrc" if standalone else "@bazel_test//:sandboxed_bazelrc"

    _bazel_test_script(
        name = script_name,
        args = args,
        bazelrc = bazelrc,
        build = build,
        check = check,
        clean_build = clean_build,
        command = command,
        config = config,
        externals = externals,
        extra_files = extra_files,
        go_version = go_version,
        targets = targets,
        workspace = workspace,
    )
    native.sh_test(
        name = name,
        size = "large",
        timeout = "moderate",
        srcs = [":" + script_name],
        tags = ["local", "bazel", "exclusive"] + tags,
        data = [
            "@bazel_gazelle//cmd/gazelle",
            bazelrc,
            "@io_bazel_rules_go//tests:rules_go_deps",
        ],
    )

def _md5_sum_impl(ctx):
    go = go_context(ctx)
    out = go.declare_file(go, ext = ".md5")
    arguments = ctx.actions.args()
    arguments.add(["-output", out.path])
    arguments.add(ctx.files.srcs)
    ctx.actions.run(
        inputs = ctx.files.srcs,
        outputs = [out],
        mnemonic = "GoMd5sum",
        executable = ctx.file._md5sum,
        arguments = [arguments],
    )
    return struct(files = depset([out]))

md5_sum = go_rule(
    _md5_sum_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
        "_md5sum": attr.label(
            allow_files = True,
            single_file = True,
            default = Label("@io_bazel_rules_go//go/tools/builders:md5sum"),
        ),
    },
)

def _test_environment_impl(ctx):
    # Find bazel
    bazel = ""
    if "BAZEL" in ctx.os.environ:
        bazel = ctx.os.environ["BAZEL"]
    elif "BAZEL_VERSION" in ctx.os.environ:
        home = ctx.os.environ["HOME"]
        bazel = home + "/.bazel/{0}/bin/bazel".format(ctx.os.environ["BAZEL_VERSION"])
    if bazel == "" or not ctx.path(bazel).exists:
        bazel = ctx.which("bazel")

    # Get a temporary directory to use as our scratch workspace
    if ctx.os.name.startswith("windows"):
        scratch_dir = ctx.os.environ["TMP"].replace("\\", "/") + "/bazel_go_test"
    else:
        result = env_execute(ctx, ["mktemp", "-d"])
        if result.return_code:
            fail("failed to create temporary directory for bazel tests: {}".format(result.stderr))
        scratch_dir = result.stdout.strip()

    # Work out where we are running so we can find externals
    exec_root, _, _ = str(ctx.path(".")).rpartition("/external/")

    # build the basic environment
    ctx.file("WORKSPACE", 'workspace(name = "{}")'.format(ctx.name))
    ctx.file("BUILD.bazel", _env_build_template.format(
        bazel = bazel,
        exec_root = exec_root,
        scratch_dir = scratch_dir,
    ))
    ctx.file("test.bazelrc", content = _bazelrc("standalone"))
    ctx.file("sandboxed_test.bazelrc", content = _bazelrc("sandboxed"))

_test_environment = repository_rule(
    attrs = {},
    environ = [
        "BAZEL",
        "BAZEL_VERSION",
        "HOME",
    ],
    implementation = _test_environment_impl,
)

def _bazel_test_settings_impl(ctx):
    return struct(
        bazel = ctx.attr.bazel,
        exec_root = ctx.attr.exec_root,
        scratch_dir = ctx.attr.scratch_dir,
    )

bazel_test_settings = rule(
    _bazel_test_settings_impl,
    attrs = {
        "bazel": attr.string(mandatory = True),
        "exec_root": attr.string(mandatory = True),
        "scratch_dir": attr.string(mandatory = True),
    },
)

def test_environment():
    _test_environment(name = "bazel_test")
