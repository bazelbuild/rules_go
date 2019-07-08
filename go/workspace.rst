Go workspace rules
==================

.. _#1986: https://github.com/bazelbuild/rules_go/issues/1986
.. _gazelle: tools/gazelle/README.rst
.. _git_repository: https://github.com/bazelbuild/bazel/blob/master/tools/build_defs/repo/git.bzl
.. _github.com/bazelbuild/bazel-skylib: https://github.com/bazelbuild/bazel-skylib
.. _github.com/gogo/protobuf: https://github.com/gogo/protobuf
.. _github.com/golang/protobuf: https://github.com/golang/protobuf/
.. _github.com/google/protobuf: https://github.com/google/protobuf/
.. _github.com/googleapis/googleapis: https://github.com/googleapis/googleapis
.. _github.com/mwitkow/go-proto-validators: https://github.com/mwitkow/go-proto-validators
.. _go_library: core.rst#go_library
.. _go_register_toolchains: toolchains.rst#go_register_toolchains
.. _go_repository: https://github.com/bazelbuild/bazel-gazelle/blob/master/repository.rst#go_repository
.. _go_toolchain: toolchains.rst#go_toolchain
.. _golang.org/x/net: https://github.com/golang/net/
.. _golang.org/x/sys: https://github.com/golang/sys/
.. _golang.org/x/text: https://github.com/golang/text/
.. _golang.org/x/tools: https://github.com/golang/tools/
.. _google.golang.org/genproto: https://github.com/google/go-genproto
.. _google.golang.org/grpc: https://github.com/grpc/grpc-go
.. _http_archive: https://github.com/bazelbuild/bazel/blob/master/tools/build_defs/repo/http.bzl
.. _nested workspaces: https://bazel.build/designs/2016/09/19/recursive-ws-parsing.html
.. _nogo: nogo.rst#nogo
.. _normal go logic: https://golang.org/cmd/go/#hdr-Remote_import_paths
.. _repositories.bzl: https://github.com/bazelbuild/rules_go/blob/master/go/private/repositories.bzl
.. _third_party: https://github.com/bazelbuild/rules_go/tree/master/third_party
.. _toolchains: toolchains.rst

.. _go_prefix_faq: /README.rst#whats-up-with-the-go_default_library-name
.. |go_prefix_faq| replace:: FAQ

.. |build_file_generation| replace:: :param:`build_file_generation`

.. role:: param(kbd)
.. role:: type(emphasis)
.. role:: value(code)
.. |mandatory| replace:: **mandatory value**

Workspace rules are either repository rules, or macros that are intended to be used from the
WORKSPACE file.

See also the `toolchains <toolchains>`_ rules, which contains the `go_register_toolchains`_
workspace rule.

.. contents:: :depth: 1

-----

go_rules_dependencies
~~~~~~~~~~~~~~~~~~~~~

``go_rules_dependencies`` is a macro that registers external dependencies needed
by the Go rules. Projects that use rules_go should *always* call it from
WORKSPACE. It may be called before or after other workspace declarations.
It must be called before ``go_register_toolchains``.

See `Overriding dependencies`_ for instructions on using a different version
of one of the repositories below.

``go_rules_dependencies`` declares the repositories in the table below.
It also declares some internal repositories not described here.

+-------------------------------------------------+-------------------------------------------+
| **Name**                                        | **Path**                                  |
+-------------------------------------------------+-------------------------------------------+
| :value:`bazel_skylib`                           | `github.com/bazelbuild/bazel-skylib`_     |
+-------------------------------------------------+-------------------------------------------+
| A library of useful Starlark functions, used in the implementation                          |
| of rules_go.                                                                                |
+-------------------------------------------------+-------------------------------------------+
| :value:`org_golang_x_tools`                     | `golang.org/x/tools`_                     |
+-------------------------------------------------+-------------------------------------------+
| The Go tools module. Provides the analysis framework that nogo_ is based on.                |
| Also provides other package loading and testing infrastructure.                             |
+-------------------------------------------------+-------------------------------------------+
| :value:`com_github_golang_protobuf`             | `github.com/golang/protobuf`_             |
+-------------------------------------------------+-------------------------------------------+
| The Go protobuf plugin and runtime. When overriding this, make sure to use                  |
| ``@io_bazel_rules_go//third_party:com_github_golang_protobuf-extras.patch``.                |
| This is needed to support both pre-generated and dynamically generated                      |
| proto libraries.                                                                            |
+-------------------------------------------------+-------------------------------------------+
| :value:`com_github_mwitkow_go_proto_validators` | `github.com/mwitkow/go-proto-validators`_ |
+-------------------------------------------------+-------------------------------------------+
| Legacy definition for proto plugin. Ideally ``go_rules_dependencies`` should                |
| not provide this.                                                                           |
+-------------------------------------------------+-------------------------------------------+
| :value:`com_github_gogo_protobuf`               | `github.com/gogo/protobuf`_               |
+-------------------------------------------------+-------------------------------------------+
| Legacy definition for proto plugins. Ideally ``go_rules_dependencies`` should               |
| not provide this.                                                                           |
+-------------------------------------------------+-------------------------------------------+
| :value:`org_golang_google_genproto`             | `google.golang.org/genproto`_             |
+-------------------------------------------------+-------------------------------------------+
| Pre-generated proto libraries for gRPC and Google APIs. Ideally,                            |
| ``go_rules_dependencies`` should provide this, but it doesn't change often,                 |
| and many things break without it.                                                           |
+-------------------------------------------------+-------------------------------------------+
| :value:`go_googleapis`                          | `github.com/googleapis/googleapis`_       |
+-------------------------------------------------+-------------------------------------------+
| Like :value:`org_golang_google_genproto` but provides ``go_proto_library``                  |
| targets instead of ``go_library``. Ideally we should use                                    |
| ``com_google_googleapis``, but Gazelle still resolves imports to this repo.                 |
| See `#1986`_.                                                                               |
+-------------------------------------------------+-------------------------------------------+

Proto dependencies
~~~~~~~~~~~~~~~~~~

In order to build ``proto_library`` and ``go_proto_library`` rules, you must
declare a repository named ``com_google_protobuf`` as below (perhaps
with a newer commit).

.. code:: bzl

    load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

    git_repository(
        name = "com_google_protobuf",
        commit = "09745575a923640154bcf307fba8aedff47f240a",
        remote = "https://github.com/protocolbuffers/protobuf",
        shallow_since = "1558721209 -0700",
    )

    load("@com_google_protobuf//:protobuf_deps.bzl", "protobuf_deps")

    protobuf_deps()

Previously, ``com_google_protobuf`` was declared by ``go_rules_dependencies``.
However, the ``protobuf_deps`` macro cannot be called from there, and
inlining it made it difficult for users to pick their own version of
``com_google_protobuf``.

gRPC dependencies
~~~~~~~~~~~~~~~~~

In order to build ``go_proto_library`` rules with the gRPC plugin,
several additional dependencies are needed. At minimum, you'll need to
declare ``org_golang_google_grpc``, ``org_golang_x_net``, and
``org_golang_x_text``.

If you're using Gazelle, and you already import ``google.golang.org/grpc``
from a .go file somewhere in your repository, and you're also using Go modules
to manage dependencies, you can generate these rules with
``bazel run //:gazelle -- update-repos -from_file=go.mod``. If you're using
dep, replace ``go.mod`` with ``Gopkg.lock`` in the above command.

Make sure you set ``build_file_proto_mode = "disable"`` on the
`go_repository`_ rule for ``org_golang_google_grpc``.

For example:

.. code:: bzl

    load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies", "go_repository")

    gazelle_dependencies()

    go_repository(
        name = "org_golang_google_grpc",
        build_file_proto_mode = "disable",
        importpath = "google.golang.org/grpc",
        sum = "h1:J0UbZOIrCAl+fpTOf8YLs4dJo8L/owV4LYVtAXQoPkw=",
        version = "v1.22.0",
    )

    go_repository(
        name = "org_golang_x_net",
        importpath = "golang.org/x/net",
        sum = "h1:oWX7TPOiFAMXLq8o0ikBYfCJVlRHBcsciT5bXOrH628=",
        version = "v0.0.0-20190311183353-d8887717615a",
    )

    go_repository(
        name = "org_golang_x_text",
        importpath = "golang.org/x/text",
        sum = "h1:g61tztE5qeGQ89tm6NTjjM9VPIm088od1l6aSorWRWg=",
        version = "v0.3.0",
    )

Overriding dependencies
~~~~~~~~~~~~~~~~~~~~~~~

You can override a dependency declared in ``go_rules_dependencies`` by
declaring a repository rule in WORKSPACE with the same name *before* the call
to ``go_rules_dependencies``.

For example, this is how you would override ``com_github_golang_protobuf``:

.. code:: bzl

    load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

    http_archive(
        name = "io_bazel_rules_go",
        urls = [
            "https://storage.googleapis.com/bazel-mirror/github.com/bazelbuild/rules_go/releases/download/0.18.7/rules_go-0.18.7.tar.gz",
            "https://github.com/bazelbuild/rules_go/releases/download/0.18.7/rules_go-0.18.7.tar.gz",
        ],
        sha256 = "45409e6c4f748baa9e05f8f6ab6efaa05739aa064e3ab94e5a1a09849c51806a",
    )

    http_archive(
        name = "bazel_gazelle",
        sha256 = "3c681998538231a2d24d0c07ed5a7658cb72bfb5fd4bf9911157c0e9ac6a2687",
        urls = ["https://github.com/bazelbuild/bazel-gazelle/releases/download/0.17.0/bazel-gazelle-0.17.0.tar.gz"],
    )

    load("@io_bazel_rules_go//go:deps.bzl", "go_rules_dependencies", "go_register_toolchains")
    load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies", "go_repository")

    go_repository(
        name = "com_github_golang_protobuf",
        build_file_proto_mode = "disable_global",
        commit = "b5d812f8a3706043e23a9cd5babf2e5423744d30",
        importpath = "github.com/golang/protobuf",
        patches = [
            "@io_bazel_rules_go//third_party:com_github_golang_protobuf-extras.patch",
        ],
        patch_args = ["-p1"],
    )

    go_rules_dependencies()

    go_register_toolchains()

    gazelle_dependencies()

Some of the dependencies declared by ``go_rules_dependencies`` require
additional patches and or adjustments compared to what `go_repository`_
generates by default (as ``com_github_golang_protobuf`` does in the example
above). Patches may be found in the `third_party`_ directory.
See notes in `repositories.bzl`_. If you're generated build files with
`go_repository`_, you do not need the ``*-gazelle.patch`` files.

go_repository
~~~~~~~~~~~~~

``go_repository`` is a repository rule defined in the Gazelle repository
that retrieves a Go module at a specific version and generates Bazel build files
using Gazelle. See `go_repository`_ for full documentation.

