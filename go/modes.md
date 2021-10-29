<!-- Generated with Stardoc: http://skydoc.bazel.build -->


  [Bazel build settings]: https://docs.bazel.build/versions/master/skylark/config.html#using-build-settings
  [Bazel configuration transitions]: https://docs.bazel.build/versions/master/skylark/lib/transition.html
  [Bazel platform]: https://docs.bazel.build/versions/master/platforms.html
  [go_library]: core.rst#go_library
  [go_binary]: core.rst#go_binary
  [go_test]: core.rst#go_test
  [toolchain]: toolchains.rst#the-toolchain-object
  [config_setting]: https://docs.bazel.build/versions/master/be/general.html#config_setting
  [platform]: https://docs.bazel.build/versions/master/be/platform.html#platform
  [select]: https://docs.bazel.build/versions/master/be/functions.html#select

# Build modes

## Contents
- [Overview](#overview)
- [Build settings](#build-settings)
- [Platforms](#platforms)
- [Examples](#examples)
  - [Building pure go binaries](#building-pure-go-binaries)
  - [Building static binaries](#building-static-binaries)
  - [Using the race detector](#using-the-race-detector)

## Additional resources
- [Bazel build settings]
- [Bazel configuration transitions]
- [Bazel platform]
- [go_library]
- [go_binary]
- [go_test]
- [toolchain]
- [config_setting]
- [platform]
- [select]

------------------------------------------------------------------------

Overview
--------

The Go toolchain can be configured to build targets in different modes using
[Bazel build settings] specified on the command line or by using attributes
specified on individual [go_binary] or [go_test] targets. For example, tests
may be run in race mode with the command line flag
`--@io_bazel_rules_go//go/config:race` or by setting `race = "on"` on the
individual test targets.

Similarly, the Go toolchain can be made to cross-compile binaries for a specific
platform by setting the `--platforms` command line flag or by setting the
`goos` and `goarch` attributes of the binary target. For example, a binary
could be built for `linux` / `arm64` using the command line flag
`--platforms=@io_bazel_rules_go//go/toolchain:linux_arm64` or by setting
`goos = "linux"` and `goarch = "arm64"`.

Build settings
--------------

The build settings below are defined in the package
`@io_bazel_rules_go//go/config`. They can all be set on the command line
or using `Bazel configuration transitions`.

TODO: generate table

Platforms
---------

You can define a [Bazel platform] using the native [platform] rule. A platform
is essentially a list of facts (constraint values) about a target platform.
rules_go defines a `platform` for each configuration the Go toolchain supports
in `@io_bazel_rules_go//go/toolchain`. There are also [config_setting] targets
in `@io_bazel_rules_go//go/platform` that can be used to pick platform-specific
sources or dependencies using [select].

You can specify a target platform using the `--platforms` command line flag.
Bazel will automatically select a registered toolchain compatible with the
target platform (rules_go registers toolchains for all supported platforms).
For example, you could build for Linux / arm64 with the flag
`--platforms=@io_bazel_rules_go//go/toolchain:linux_arm64`.

You can set the `goos` and `goarch` attributes on an individual
[go_binary] or [go_test] rule to build a binary for a specific platform.
This sets the `--platforms` flag via [Bazel configuration transitions].


Examples
--------

Building pure go binaries
-------------------------

You can switch the default binaries to non cgo using

``` bash
bazel build --@io_bazel_rules_go//go/config:pure //:my_binary
```

You can build pure go binaries by setting those attributes on a binary.

``` bzl
go_binary(
    name = "foo",
    srcs = ["foo.go"],
    pure = "on",
)
```


Building static binaries
------------------------

| Note that static linking does not work on darwin.

You can switch the default binaries to statically linked binaries using

``` bash
bazel build --@io_bazel_rules_go//go/config:static //:my_binary
```

You can build static go binaries by setting those attributes on a binary.
If you want it to be fully static (no libc), you should also specify pure.

``` bzl
go_binary(
    name = "foo",
    srcs = ["foo.go"],
    static = "on",
)
```

Using the race detector
-----------------------

You can switch the default binaries to race detection mode, and thus also switch
the mode of tests by using

``` bash
bazel test --@io_bazel_rules_go//go/config:race //...
```

Alternatively, you can activate race detection for specific tests.

``` bzl
go_test(
    name = "go_default_test",
    srcs = ["lib_test.go"],
    embed = [":go_default_library"],
    race = "on",
)
```


<a id="#extld_from_cc_toolchain"></a>

## extld_from_cc_toolchain

<pre>
extld_from_cc_toolchain(<a href="#extld_from_cc_toolchain-go">go</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="extld_from_cc_toolchain-go"></a>go |  <p align="center"> - </p>   |  none |


<a id="#extldflags_from_cc_toolchain"></a>

## extldflags_from_cc_toolchain

<pre>
extldflags_from_cc_toolchain(<a href="#extldflags_from_cc_toolchain-go">go</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="extldflags_from_cc_toolchain-go"></a>go |  <p align="center"> - </p>   |  none |


<a id="#get_mode"></a>

## get_mode

<pre>
get_mode(<a href="#get_mode-ctx">ctx</a>, <a href="#get_mode-go_toolchain">go_toolchain</a>, <a href="#get_mode-cgo_context_info">cgo_context_info</a>, <a href="#get_mode-go_config_info">go_config_info</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="get_mode-ctx"></a>ctx |  <p align="center"> - </p>   |  none |
| <a id="get_mode-go_toolchain"></a>go_toolchain |  <p align="center"> - </p>   |  none |
| <a id="get_mode-cgo_context_info"></a>cgo_context_info |  <p align="center"> - </p>   |  none |
| <a id="get_mode-go_config_info"></a>go_config_info |  <p align="center"> - </p>   |  none |


<a id="#installsuffix"></a>

## installsuffix

<pre>
installsuffix(<a href="#installsuffix-mode">mode</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="installsuffix-mode"></a>mode |  <p align="center"> - </p>   |  none |


<a id="#link_mode_args"></a>

## link_mode_args

<pre>
link_mode_args(<a href="#link_mode_args-mode">mode</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="link_mode_args-mode"></a>mode |  <p align="center"> - </p>   |  none |


<a id="#mode_string"></a>

## mode_string

<pre>
mode_string(<a href="#mode_string-mode">mode</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="mode_string-mode"></a>mode |  <p align="center"> - </p>   |  none |


<a id="#mode_tags_equivalent"></a>

## mode_tags_equivalent

<pre>
mode_tags_equivalent(<a href="#mode_tags_equivalent-l">l</a>, <a href="#mode_tags_equivalent-r">r</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="mode_tags_equivalent-l"></a>l |  <p align="center"> - </p>   |  none |
| <a id="mode_tags_equivalent-r"></a>r |  <p align="center"> - </p>   |  none |


