Go workspace rules
==================

.. _github.com/google/protobuf: https://github.com/google/protobuf/
.. _github.com/golang/protobuf: https://github.com/golang/protobuf/
.. _google.golang.org/genproto: https://github.com/google/go-genproto
.. _google.golang.org/grpc: https://github.com/grpc/grpc-go
.. _golang.org/x/net: https://github.com/golang/net/
.. _golang.org/x/text: https://github.com/golang/text/
.. _golang.org/x/tools: https://github.com/golang/tools/
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

* :value:`com_google_protobuf` : An http_archive for `github.com/google/protobuf`_
* :value:`com_github_golang_protobuf` : A go_repository for `github.com/golang/protobuf`_
* :value:`org_golang_google_genproto` : A go_repository for `google.golang.org/genproto`_
* :value:`org_golang_google_grpc` : A go_repository for `google.golang.org/grpc`_
* :value:`org_golang_x_net` : A go_repository for `golang.org/x/net`_
* :value:`org_golang_x_text` : A go_repository for `golang.org/x/text`_
* :value:`org_golang_x_tools` : A go_repository for `golang.org/x/tools`_


It won't override repositories that were declared earlier, so you can replace any of these with
a different version by declaring it before calling this macro, which is why we recommend you should
put the call at the bottom of your WORKSPACE. For example:

.. code:: bzl

  go_repository(
      name = "org_golang_x_net",
      commit = "0744d001aa8470aaa53df28d32e5ceeb8af9bd70",
      importpath = "golang.org/x/net",
  )

  go_rules_dependencies()

would cause the go rules to use the specified version of x/net.

go_repository
~~~~~~~~~~~~~

This rule has moved. See `go_repository`_ in the Gazelle repository.
