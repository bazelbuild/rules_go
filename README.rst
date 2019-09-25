Go rules for Bazel_
=====================

.. All external links are here
.. _Bazel: https://bazel.build/
.. |bazelci| image:: https://badge.buildkite.com/7ff4772cf73f716565daee2e0e6f4c8d8dee2b086caf27b6a8.svg
  :target: https://buildkite.com/bazel/golang-rules-go
.. _gazelle: https://github.com/bazelbuild/bazel-gazelle
.. _gazelle update-repos: https://github.com/bazelbuild/bazel-gazelle#update-repos
.. _github.com/bazelbuild/bazel-gazelle: https://github.com/bazelbuild/bazel-gazelle
.. _vendoring: Vendoring.md
.. _protocol buffers: proto/core.rst
.. _go_repository: https://github.com/bazelbuild/bazel-gazelle/blob/master/repository.rst#go_repository
.. _go_library: go/core.rst#go_library
.. _go_binary: go/core.rst#go_binary
.. _go_test: go/core.rst#go_test
.. _go_download_sdk: go/toolchains.rst#go_download_sdk
.. _go_rules_dependencies: go/workspace.rst#go_rules_dependencies
.. _go_register_toolchains: go/toolchains.rst#go_register_toolchains
.. _go_proto_library: proto/core.rst#go_proto_library
.. _go_proto_compiler: proto/core.rst#go_proto_compiler
.. _bazel-go-discuss: https://groups.google.com/forum/#!forum/bazel-go-discuss
.. _Bazel labels: https://docs.bazel.build/versions/master/build-ref.html#labels
.. _#265: https://github.com/bazelbuild/rules_go/issues/265
.. _#721: https://github.com/bazelbuild/rules_go/issues/721
.. _#889: https://github.com/bazelbuild/rules_go/issues/889
.. _#1199: https://github.com/bazelbuild/rules_go/issues/1199
.. _//tests/core/cross: https://github.com/bazelbuild/rules_go/blob/master/tests/core/cross/BUILD.bazel
.. _Running Bazel Tests on Travis CI: https://kev.inburke.com/kevin/bazel-tests-on-travis-ci/
.. _korfuri/bazel-travis Use Bazel with Travis CI: https://github.com/korfuri/bazel-travis
.. _rules_go and Gazelle roadmap: roadmap.rst
.. _Deprecation schedule: deprecation.rst
.. _Avoiding conflicts: proto/core.rst#avoiding-conflicts
.. _Proto dependencies: go/workspace.rst#proto-dependencies
.. _gRPC dependencies: go/workspace.rst#grpc-dependencies
.. _Overriding dependencies: go/workspace.rst#overriding-dependencies
.. _nogo: go/nogo.rst
.. _Using rules_go on Windows: windows.rst

.. ;; And now we continue with the actual content


|bazelci|

Mailing list: `bazel-go-discuss`_

Announcements
-------------

2019-09-25
  Releases
  `v0.19.5 <https://github.com/bazelbuild/rules_go/releases/tag/v0.19.5>`_ and
  `v0.18.11 <https://github.com/bazelbuild/rules_go/releases/tag/v0.18.11>`_ are
  now available with support for Go 1.13.1 and 1.12.10.
2019-09-04
  Releases
  `0.19.4 <https://github.com/bazelbuild/rules_go/releases/tag/0.19.4>`_ and
  `0.18.10 <https://github.com/bazelbuild/rules_go/releases/tag/0.18.10>`_ are
  now available with support for Go 1.13.
2019-08-15
  Releases
  `0.19.3 <https://github.com/bazelbuild/rules_go/releases/tag/0.19.3>`_ and
  `0.18.9 <https://github.com/bazelbuild/rules_go/releases/tag/0.18.9>`_ are
  now available with support for Go 1.12.9.

Contents
--------

.. contents:: .
  :depth: 2

Documentation
~~~~~~~~~~~~~

* `Core API <go/core.rst>`_

  * `go_binary`_
  * `go_library`_
  * `go_test`_

* `Workspace rules <go/workspace.rst>`_
* `Protobuf rules <proto/core.rst>`_

  * `go_proto_library`_
  * `go_proto_compiler`_

* `Toolchains <go/toolchains.rst>`_
* `Extra rules <go/extras.rst>`_
* `nogo build-time code analysis <go/nogo.rst>`_
* `Build modes <go/modes.rst>`_

Quick links
~~~~~~~~~~~

* `rules_go and Gazelle roadmap`_
* `Deprecation schedule`_
* `Using rules_go on Windows`_

Overview
--------

The rules are in the beta stage of development. They support:

* `libraries <go_library_>`_
* `binaries <go_binary_>`_
* `tests <go_test_>`_
* vendoring_
* cgo
* cross compilation
* auto generating BUILD files via gazelle_
* build-time code analysis via nogo_
* `protocol buffers`_

They currently do not support (in order of importance):

* bazel-style auto generating BUILD (where the library name is other than
  go_default_library)
* C/C++ interoperation except cgo (swig etc.)
* coverage

Note: The latest version of these rules (0.19.5) requires Bazel ≥ 0.23.0 to work.

The ``master`` branch is only guaranteed to work with the latest version of Bazel.


Setup
-----

* Create a file at the top of your repository named WORKSPACE and add one
  of the snippets below, verbatim. This will let Bazel fetch necessary
  dependencies from this repository and a few others.

  If you want to use the latest stable release, add the following:

  .. code:: bzl

    load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

    http_archive(
        name = "io_bazel_rules_go",
        urls = [
            "https://storage.googleapis.com/bazel-mirror/github.com/bazelbuild/rules_go/releases/download/v0.19.5/rules_go-v0.19.5.tar.gz",
            "https://github.com/bazelbuild/rules_go/releases/download/v0.19.5/rules_go-v0.19.5.tar.gz",
        ],
        sha256 = "513c12397db1bc9aa46dd62f02dd94b49a9b5d17444d49b5a04c5a89f3053c1c",
    )

    load("@io_bazel_rules_go//go:deps.bzl", "go_rules_dependencies", "go_register_toolchains")

    go_rules_dependencies()

    go_register_toolchains()

  If you want to use a specific commit (for example, something close to
  ``master``), add the following instead:

  .. code:: bzl

    load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

    git_repository(
        name = "io_bazel_rules_go",
        remote = "https://github.com/bazelbuild/rules_go.git",
        commit = "f5cfc31d4e8de28bf19d0fb1da2ab8f4be0d2cde",
    )

    load("@io_bazel_rules_go//go:deps.bzl", "go_rules_dependencies", "go_register_toolchains")

    go_rules_dependencies()

    go_register_toolchains()

  You can add more external dependencies to this file later (see
  `go_repository`_).

* Add a file named ``BUILD.bazel`` in the root directory of your
  project. In general, you need one of these files in every directory
  with Go code, but you need one in the root directory even if your project
  doesn't have any Go code there.

* If your project can be built with ``go build``, you can
  `generate your build files <Generating build files_>`_ using Gazelle. If your
  project isn't compatible with `go build` or if you prefer not to use Gazelle,
  you can `write build files by hand <Writing build files by hand_>`_.

Generating build files
~~~~~~~~~~~~~~~~~~~~~~

If your project can be built with ``go build``, you can generate and update your
build files automatically using gazelle_.

* Add the ``bazel_gazelle`` repository and its dependencies to your WORKSPACE
  file before ``go_rules_dependencies`` is called. It should look like this:

  .. code:: bzl

    load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

    http_archive(
        name = "io_bazel_rules_go",
        urls = [
            "https://storage.googleapis.com/bazel-mirror/github.com/bazelbuild/rules_go/releases/download/v0.19.5/rules_go-v0.19.5.tar.gz",
            "https://github.com/bazelbuild/rules_go/releases/download/v0.19.5/rules_go-v0.19.5.tar.gz",
        ],
        sha256 = "513c12397db1bc9aa46dd62f02dd94b49a9b5d17444d49b5a04c5a89f3053c1c",
    )

    load("@io_bazel_rules_go//go:deps.bzl", "go_rules_dependencies", "go_register_toolchains")

    go_rules_dependencies()

    go_register_toolchains()

    http_archive(
        name = "bazel_gazelle",
        urls = [
            "https://storage.googleapis.com/bazel-mirror/github.com/bazelbuild/bazel-gazelle/releases/download/0.18.2/bazel-gazelle-0.18.2.tar.gz",
            "https://github.com/bazelbuild/bazel-gazelle/releases/download/0.18.2/bazel-gazelle-0.18.2.tar.gz",
        ],
        sha256 = "7fc87f4170011201b1690326e8c16c5d802836e3a0d617d8f75c3af2b23180c4",
    )

    load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")

    gazelle_dependencies()

* Add the code below to the BUILD or BUILD.bazel file in the root directory
  of your repository. Replace the string after ``prefix`` with the prefix you
  chose for your project earlier.

  .. code:: bzl

    load("@bazel_gazelle//:def.bzl", "gazelle")

    # gazelle:prefix github.com/example/project
    gazelle(name = "gazelle")

* After adding the ``gazelle`` rule, run the command below:

  ::

    bazel run //:gazelle


  This will generate a ``BUILD.bazel`` file for each Go package in your
  repository.  You can run the same command in the future to update existing
  build files with new source files, dependencies, and options.

Writing build files by hand
~~~~~~~~~~~~~~~~~~~~~~~~~~~

If your project doesn't follow ``go build`` conventions or you prefer not to use
gazelle_, you can write build files by hand.

* In each directory that contains Go code, create a file named ``BUILD.bazel``
* Add a ``load`` statement at the top of the file for the rules you use.

  .. code:: bzl

    load("@io_bazel_rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

* For each library, add a go_library_ rule like the one below.
  Source files are listed in ``srcs``. Other packages you import are listed in
  ``deps`` using `Bazel labels`_
  that refer to other go_library_ rules. The library's import path should
  be specified with ``importpath``.

  .. code:: bzl

    go_library(
        name = "go_default_library",
        srcs = [
            "foo.go",
            "bar.go",
        ],
        deps = [
            "//tools:go_default_library",
            "@org_golang_x_utils//stuff:go_default_library",
        ],
        importpath = "github.com/example/project/foo",
        visibility = ["//visibility:public"],
    )

* For each test, add a go_test_ rule like either of the ones below.
  You'll need separate go_test_ rules for internal and external tests.

  .. code:: bzl

    # Internal test
    go_test(
        name = "go_default_test",
        srcs = ["foo_test.go"],
        importpath = "github.com/example/project/foo",
        embed = [":go_default_library"],
    )

    # External test
    go_test(
        name = "go_default_xtest",
        srcs = ["bar_test.go"],
        deps = [":go_default_library"],
        importpath = "github.com/example/project/foo",
    )

* For each binary, add a go_binary_ rule like the one below.

  .. code:: bzl

    go_binary(
        name = "foo",
        srcs = ["main.go"],
        deps = [":go_default_library"],
    )

Adding external repositories
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

For each Go repository, add a `go_repository`_ rule like the one below.
This rule comes from the Gazelle repository, so you will need to load it.
`gazelle update-repos`_ can generate or update these rules automatically from
a go.mod or Gopkg.lock file.

.. code:: bzl

    load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

    # Download the Go rules
    http_archive(
        name = "io_bazel_rules_go",
        urls = [
            "https://storage.googleapis.com/bazel-mirror/github.com/bazelbuild/rules_go/releases/download/v0.19.5/rules_go-v0.19.5.tar.gz",
            "https://github.com/bazelbuild/rules_go/releases/download/v0.19.5/rules_go-v0.19.5.tar.gz",
        ],
        sha256 = "513c12397db1bc9aa46dd62f02dd94b49a9b5d17444d49b5a04c5a89f3053c1c",
    )

    # Load and call the dependencies
    load("@io_bazel_rules_go//go:deps.bzl", "go_rules_dependencies", "go_register_toolchains")

    go_rules_dependencies()

    go_register_toolchains()

    # Download Gazelle
    http_archive(
        name = "bazel_gazelle",
        urls = [
            "https://storage.googleapis.com/bazel-mirror/github.com/bazelbuild/bazel-gazelle/releases/download/0.18.2/bazel-gazelle-0.18.2.tar.gz",
            "https://github.com/bazelbuild/bazel-gazelle/releases/download/0.18.2/bazel-gazelle-0.18.2.tar.gz",
        ],
        sha256 = "7fc87f4170011201b1690326e8c16c5d802836e3a0d617d8f75c3af2b23180c4",
    )

    # Load and call Gazelle dependencies
    load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies", "go_repository")

    gazelle_dependencies()

    # Add a go repository
    go_repository(
        name = "com_github_pkg_errors",
        importpath = "github.com/pkg/errors",
        sum = "h1:iURUrRGxPUNPdy5/HRSm+Yj6okJ6UtLINN0Q9M4+h3I=",
        version = "v0.8.1",
    )

FAQ
---

Can I still use the ``go`` tool?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Yes, this setup was deliberately chosen to be compatible with ``go build``.
Make sure your project appears in ``GOPATH`` or has a go.mod file, and it should
work.

Note that ``go build`` won't be aware of dependencies listed in ``WORKSPACE``,
so you may want to download your dependencies into your ``GOPATH`` or module
cache so that your tools are aware of them.  You may also need to check in
generated files.

Does this work with Go modules?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Yes, but not directly. Modules are a dependency management feature in cmd/go,
the build system that ships with the Go SDK. Bazel uses the Go compiler and
linker in the Go toolchain, but it does not use cmd/go. You need to describe
your Go packages and executables and their dependencies in ``go_library``,
``go_binary``, and ``go_test`` rules written in build files, and you need to
describe your external dependencies in Bazel's WORKSPACE file.

If your project follows normal Go conventions (those required by cmd/go), you
can generate and update build files using gazelle_. You can import external
dependencies from your go.mod file with a command like ``gazelle update-repos
-from_file=go.mod``. This will add `go_repository`_ rules to your WORKSPACE.
Each `go_repository`_ rule can download a module and generate build files for
the module's packages using Gazelle. See `gazelle update-repos`_ for more
information.

What's up with the ``go_default_library`` name?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This was used to keep import paths consistent in libraries that can be built
with ``go build`` before the ``importpath`` attribute was available.

In order to compile and link correctly, rules_go must know the Go import path
(the string by which a package can be imported) for each library. This is now
set explicitly with the ``importpath`` attribute. Before that attribute existed,
the import path was inferred by concatenating a string from a special
``go_prefix`` rule and the library's package and label name. For example, if
``go_prefix`` was ``github.com/example/project``, for a library
``//foo/bar:bar``, rules_go would infer the import path as
``github.com/example/project/foo/bar/bar``. The stutter at the end is
incompatible with ``go build``, so if the label name was ``go_default_library``,
the import path would not include it. So for the library
``//foo/bar:go_default_library``, the import path would be
``github.com/example/project/foo/bar``.

Since ``go_prefix`` was removed and the ``importpath`` attribute became
mandatory (see `#721`_), the ``go_default_library`` name no longer serves any
purpose. We may decide to stop using it in the future (see `#265`_).

How do I access testdata?
~~~~~~~~~~~~~~~~~~~~~~~~~

Bazel executes tests in a sandbox, which means tests don't automatically have
access to files. You must include test files using the ``data`` attribute.
For example, if you want to include everything in the ``testdata`` directory:

.. code:: bzl

  go_test(
      name = "go_default_test",
      srcs = ["foo_test.go"],
      data = glob(["testdata/**"]),
      importpath = "github.com/example/project/foo",
  )

By default, tests are run in the directory of the build file that defined them.
Note that this follows the Go testing convention, not the Bazel convention
followed by other languages, which run in the repository root. This means
that you can access test files using relative paths. You can change the test
directory using the ``rundir`` attribute. See go_test_.

Gazelle will automatically add a ``data`` attribute like the one above if you
have a ``testdata`` directory *unless* it contains buildable .go files or
build files, in which case, ``testdata`` is treated as a normal package.

How do I cross-compile?
~~~~~~~~~~~~~~~~~~~~~~~

You can cross-compile by setting the ``--platforms`` flag on the command line.
For example:

.. code::

  $ bazel build --platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 //cmd

By default, cgo is disabled when cross-compiling. To cross-compile with cgo,
add a ``_cgo`` suffix to the target platform. You must register a
cross-compiling C/C++ toolchain with Bazel for this to work.

.. code::

  $ bazel build --platforms=@io_bazel_rules_go//go/toolchain:linux_amd64_cgo //cmd

Platform-specific sources with build tags or filename suffixes are filtered
automatically at compile time. You can selectively include platform-specific
dependencies with ``select`` expressions (Gazelle does this automatically).

.. code:: bzl

  go_library(
      name = "go_default_library",
      srcs = [
          "foo_linux.go",
          "foo_windows.go",
      ],
      deps = select({
          "@io_bazel_rules_go//go/platform:linux_amd64": [
              "//bar_linux:go_default_library",
          ],
          "@io_bazel_rules_go//go/platform:windows_amd64": [
              "//bar_windows:go_default_library",
          ],
          "//conditions:default": [],
      }),
  )

rules_go can generate pure Go binaries for any platform the Go SDK supports. If
your project includes cgo code, has C/C++ dependencies, or requires external
linking, you'll need to `write a CROSSTOOL file
<https://github.com/bazelbuild/bazel/wiki/Yet-Another-CROSSTOOL-Writing-Tutorial>`_
for your toolchain and set the ``--cpu`` flag on the command line, in addition
to setting ``--platforms``. You'll also need to set ``pure = "off"`` on your
``go_binary``. We don't fully support this yet, but people have gotten this to
work in some cases.

In some cases, you may want to set the ``goos`` and ``goarch`` attributes of
``go_binary``. This will cross-compile a binary for a specific platform.
This is necessary when you need to produce multiple binaries for different
platforms in a single build. However, note that ``select`` expressions will
not work correctly when using these attributes.

How do I access ``go_binary`` executables from ``go_test``?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The location where ``go_binary`` writes its executable file is not stable across
rules_go versions and should not be depended upon. The parent directory includes
some configuration data in its name. This prevents Bazel's cache from being
poisoned when the same binary is built in different configurations. The binary
basename may also be platform-dependent: on Windows, we add an .exe extension.

To depend on an executable in a ``go_test`` rule, reference the executable
in the ``data`` attribute (to make it visible), then expand the location
in ``args``. The real location will be passed to the test on the command line.
For example:

.. code:: bzl

  go_binary(
      name = "cmd",
      srcs = ["cmd.go"],
  )

  go_test(
      name = "cmd_test",
      srcs = ["cmd_test.go"],
      args = ["$(location :cmd)"],
      data = [":cmd"],
  )

See `//tests/core/cross`_ for a full example of a test that
accesses a binary.

Alternatively, you can set the ``out`` attribute of `go_binary`_ to a specific
filename. Note that when ``out`` is set, the binary won't be cached when
changing configurations.

.. code:: bzl

  go_binary(
      name = "cmd",
      srcs = ["cmd.go"],
      out = "cmd",
  )

  go_test(
      name = "cmd_test",
      srcs = ["cmd_test.go"],
      data = [":cmd"],
  )

How do I run Bazel on Travis CI?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

References:

* `Running Bazel Tests on Travis CI`_ by Kevin Burke
* `korfuri/bazel-travis Use Bazel with Travis CI`_

In order to run Bazel tests on Travis CI, you'll need to install Bazel in the
``before_install`` script. See our configuration file linked above.

You'll want to run Bazel with a number of flags to prevent it from consuming
a huge amount of memory in the test environment.

* ``--host_jvm_args=-Xmx500m --host_jvm_args=-Xms500m``: Set the maximum and
  initial JVM heap size. Keeping the same means the JVM won't spend time
  growing the heap. The choice of heap size is somewhat arbitrary; other
  configuration files recommend limits as high as 2500m. Higher values mean
  a faster build, but higher risk of OOM kill.
* ``--bazelrc=.test-bazelrc``: Use a Bazel configuration file specific to
  Travis CI. You can put most of the remaining options in here.
* ``build --spawn_strategy=standalone --genrule_strategy=standalone``: Disable
  sandboxing for the build. Sandboxing may fail inside of Travis's containers
  because the ``mount`` system call is not permitted.
* ``test --test_strategy=standalone``: Disable sandboxing for tests as well.
* ``--local_resources=1536,1.5,0.5``: Set Bazel limits on available RAM in MB,
  available cores for compute, and available cores for I/O. Higher values
  mean a faster build, but higher contention and risk of OOM kill.
* ``--noshow_progress``: Suppress progress messages in output for cleaner logs.
* ``--verbose_failures``: Get more detailed failure messages.
* ``--test_output=errors``: Show test stderr in the Travis log. Normally,
  test output is written log files which Travis does not save or report.

Downloads on Travis are relatively slow (the network is heavily
contended), so you'll want to minimize the amount of network I/O in
your build. Downloading Bazel and a Go SDK is a huge part of that. To
avoid downloading a Go SDK, you may request a container with a
preinstalled version of Go in your ``.travis.yml`` file, then call
``go_register_toolchains(go_version = "host")`` in a Travis-specific
``WORKSPACE`` file.

You may be tempted to put Bazel's cache in your Travis cache. Although this
can speed up your build significantly, Travis stores its cache on Amazon, and
it takes a very long time to transfer. Clean builds seem faster in practice.

How do I test a beta version of the Go SDK?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

rules_go only supports official releases of the Go SDK. However, we do have
an easy way for developers to try out beta releases.

In your WORKSPACE file, add a call `go_download_sdk`_ like the one below. This
must be named ``go_sdk``, and it must come *before* the call to
`go_register_toolchains`_.

.. code:: bzl

  load("@io_bazel_rules_go//go:deps.bzl",
      "go_download_sdk",
      "go_register_toolchains",
      "go_rules_dependencies",
  )

  go_rules_dependencies()

  go_download_sdk(
      name = "go_sdk",
      sdks = {
          "darwin_amd64": ("go1.10beta1.darwin-amd64.tar.gz", "8c2a4743359f4b14bcfaf27f12567e3cbfafc809ed5825a2238c0ba45db3a8b4"),
          "linux_amd64":  ("go1.10beta1.linux-amd64.tar.gz", "ec7a10b5bf147a8e06cf64e27384ff3c6d065c74ebd8fdd31f572714f74a1055"),
      },
  )

  go_register_toolchains()


How do I get information about the Go SDK used by rules_go?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

You can run: ``bazel build @io_bazel_rules_go//:go_info`` which outputs
``go_info_report`` with information like the used Golang version.

How do I avoid conflicts with protocol buffers?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

See `Avoiding conflicts`_ in the proto documentation.

How do I build proto libraries and gRPC?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The `go_rules_dependencies`_ macro used to declare all dependencies needed
to generate and compile protocol buffers. Managing this got too complicated,
and the declarations caused confusion in workspaces that declared different
versions of the same repositories, so these dependencies are no longer
declared in ``go_rules_dependencies``. They must be declared separately.

In order to build anything that uses ``protoc`` (including ``proto_library``),
you must declare a repository rule for ``com_google_protobuf``. See
`Proto dependencies`_ for an example.

In order to build anything that uses gRPC, several additional repositories
must be declared. See `gRPC dependencies`_ for instructions and an example.

Can I use a vendored gRPC with go_proto_library?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This is not supported. When using `go_proto_library`_ with the
``@io_bazel_rules_go//proto:go_grpc`` compiler, an implicit dependency is added
on ``@org_golang_google_grpc//:go_default_library``. If you link another copy of
the same package from ``//vendor/google.golang.org/grpc:go_default_library``
or anywhere else, you may experience conflicts at compile or run-time.

If you're using Gazelle with proto rule generation enabled, imports of
``google.golang.org/grpc`` will be automatically resolved to
``@org_golang_google_grpc//:go_default_library`` to avoid conflicts. The
vendored gRPC should be ignored in this case.

If you specifically need to use a vendored gRPC package, it's best to avoid
using ``go_proto_library`` altogether. You can check in pre-generated .pb.go
files and build them with ``go_library`` rules. Gazelle will generate these
rules when proto rule generation is disabled (add ``# gazelle:proto
disable_global`` to your root build file).
