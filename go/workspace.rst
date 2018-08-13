Go workspace rules
==================

.. _github.com/google/protobuf: https://github.com/google/protobuf/
.. _github.com/golang/protobuf: https://github.com/golang/protobuf/
.. _google.golang.org/genproto: https://github.com/google/go-genproto
.. _google.golang.org/grpc: https://github.com/grpc/grpc-go
.. _golang.org/x/net: https://github.com/golang/net/
.. _golang.org/x/text: https://github.com/golang/text/
.. _golang.org/x/tools: https://github.com/golang/tools/
.. _golang.org/x/sys: https://github.com/golang/sys/
.. _go_library: core.rst#go_library
.. _toolchains: toolchains.rst
.. _go_register_toolchains: toolchains.rst#go_register_toolchains
.. _go_toolchain: toolchains.rst#go_toolchain
.. _normal go logic: https://golang.org/cmd/go/#hdr-Remote_import_paths
.. _gazelle: tools/gazelle/README.rst
.. _http_archive: https://docs.bazel.build/versions/master/be/workspace.html#http_archive
.. _git_repository: https://docs.bazel.build/versions/master/be/workspace.html#git_repository
.. _nested workspaces: https://bazel.build/designs/2016/09/19/recursive-ws-parsing.html
.. _go_repository: https://github.com/bazelbuild/bazel-gazelle/blob/master/repository.rst#go_repository

.. _go_prefix_faq: /README.rst#whats-up-with-the-go_default_library-name
.. |go_prefix_faq| replace:: FAQ

.. |build_file_generation| replace:: :param:`build_file_generation`

.. role:: param(kbd)
.. role:: type(emphasis)
.. role:: value(code)
.. |mandatory| replace:: **mandatory value**

Workspace rules are either repository rules, or macros that are intended to be used from the
WORKSPACE file.

See also the `toolchains <toolchains>`_ rules, which contains the go_register_toolchains_
workspace rule.

.. contents:: :depth: 1

-----

go_rules_dependencies
~~~~~~~~~~~~~~~~~~~~~

Registers external dependencies needed by rules_go, including the Go toolchain and standard
library.
All the other workspace rules and build rules assume that this rule is placed in the WORKSPACE.

When `nested workspaces`_  arrive this will be redundant, but for now you should **always** call
this macro from your WORKSPACE.

The macro takes no arguments and returns no results. You put

.. code:: bzl

  go_rules_dependencies()

in the bottom of your WORKSPACE file and forget about it.


The list of dependencies it adds is quite long, there are a few listed below that you are more
likely to want to know about and override, but it is by no means a complete list.

* :value:`com_google_protobuf` : `github.com/google/protobuf`_
* :value:`com_github_golang_protobuf` : `github.com/golang/protobuf`_
* :value:`org_golang_google_genproto` : `google.golang.org/genproto`_
* :value:`org_golang_google_grpc` : `google.golang.org/grpc`_
* :value:`org_golang_x_net` : `golang.org/x/net`_
* :value:`org_golang_x_text` : `golang.org/x/text`_
* :value:`org_golang_x_tools` : `golang.org/x/tools`_
* :value:`org_golang_x_sys`: `golang.org/x/sys`_


It won't override repositories that were declared earlier, so you can replace
any of these with a different version by declaring it before calling this macro.

go_repository
~~~~~~~~~~~~~

This rule has moved. See `go_repository`_ in the Gazelle repository.

Overriding dependencies
~~~~~~~~~~~~~~~~~~~~~~~

You can override a dependency declared in ``go_rules_dependencies`` by
declaring a repository rule in WORKSPACE with the same name *before* the call
to ``go_rules_dependencies``.

For example, this is how you would override ``org_golang_x_sys``.

.. code:: bzl

    load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

    http_archive(
        name = "io_bazel_rules_go",
        urls = ["https://github.com/bazelbuild/rules_go/releases/download/0.14.0/rules_go-0.14.0.tar.gz"],
        sha256 = "5756a4ad75b3703eb68249d50e23f5d64eaf1593e886b9aa931aa6e938c4e301",
    )

    http_archive(
        name = "bazel_gazelle",
        urls = ["https://github.com/bazelbuild/bazel-gazelle/releases/download/0.14.0/bazel-gazelle-0.14.0.tar.gz"],
        sha256 = "c0a5739d12c6d05b6c1ad56f2200cb0b57c5a70e03ebd2f7b87ce88cabf09c7b",
    )

    load("@bazel_gazelle//:deps.bzl", "go_repository")

    go_repository(
        name = "org_golang_x_sys",
        commit = "57f5ac02873b2752783ca8c3c763a20f911e4d89",
        importpath = "golang.org/x/sys",
    )

    load("@io_bazel_rules_go//go:def.bzl", "go_register_toolchains", "go_rules_dependencies")

    go_rules_dependencies()

    go_register_toolchains()

    load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies")

    gazelle_dependencies()
