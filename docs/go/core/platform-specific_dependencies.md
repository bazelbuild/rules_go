  [build constraints]: https://golang.org/pkg/go/build/#hdr-Build_Constraints
  [select]: https://docs.bazel.build/versions/master/be/functions.html#select
  [config_setting]: https://docs.bazel.build/versions/master/be/general.html#config_setting
  [Gazelle]: https://github.com/bazelbuild/bazel-gazelle


## Platform-specific dependencies

When cross-compiling, you may have some platform-specific sources and
dependencies. Source files from all platforms can be mixed freely in a single
`srcs` list. Source files are filtered using [build constraints] (filename
suffixes and `+build` tags) before being passed to the compiler.

Platform-specific dependencies are another story. For example, if you are
building a binary for Linux, and it has dependency that should only be built
when targeting Windows, you will need to filter it out using Bazel [select]
expressions:

``` bzl
go_binary(
    name = "cmd",
    srcs = [
        "foo_linux.go",
        "foo_windows.go",
    ],
    deps = [
        # platform agnostic dependencies
        "//bar",
    ] + select({
        # OS-specific dependencies
        "@io_bazel_rules_go//go/platform:linux": [
            "//baz_linux",
        ],
        "@io_bazel_rules_go//go/platform:windows": [
            "//quux_windows",
        ],
        "//conditions:default": [],
    }),
)
```

`select` accepts a dictionary argument. The keys are labels that reference [config_setting] rules.
The values are lists of labels. Exactly one of these
lists will be selected, depending on the target configuration. rules_go has
pre-declared `config_setting` rules for each OS, architecture, and
OS-architecture pair. For a full list, run this command:

``` bash
$ bazel query 'kind(config_setting, @io_bazel_rules_go//go/platform:all)'
```

[Gazelle] will generate dependencies in this format automatically.

