Go workspace rules
==================

.. _github.com/google/protobuf: https://github.com/google/protobuf/
.. _github.com/golang/protobuf: https://github.com/golang/protobuf/
.. _google.golang.org/grpc: https://github.com/grpc/grpc-go
.. _golang.org/x/net: https://github.com/golang/net/
.. _golang.org/x/tools: https://github.com/golang/tools/
.. _go_library: core.rst#go_library
.. _toolchains: toolchains.rst
.. _go_register_toolchains: toolchains.rst#go_register_toolchains
.. _go_sdk: toolchains.rst#go_sdk
.. _go_toolchain: toolchains.rst#go_toolchain
.. _new_go_repository: deprecated.rst#new_go_repository
.. _go_repositories: deprecated.rst#go_repositories
.. _normal go logic: https://golang.org/cmd/go/#hdr-Remote_import_paths
.. _gazelle: tools/gazelle/README.md
.. _http_archive: https://docs.bazel.build/versions/master/be/workspace.html#http_archive
.. _git_repository: https://docs.bazel.build/versions/master/be/workspace.html#git_repository
.. _nested workspaces: https://bazel.build/designs/2016/09/19/recursive-ws-parsing.html

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

There is also the deprecated new_go_repository_ and go_repositories_ which you should no longer use
(we will be deleting them soon).


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
* :value:`org_golang_google_grpc` : A go_repository for `google.golang.org/grpc`_
* :value:`org_golang_x_net` : A go_repository for `golang.org/x/net`_
* :value:`org_golang_x_tools` : A go_repository for `golang.org/x/tools`_


It won't override repositories that were declared earlier, so you can replace any of these with
a different version by declaring it before calling this macro, which is why we recommend you should
put the call at the bottom of your WORKSPACE. For example:

.. code:: bzl

  go_repository,
      name = "org_golang_x_net",
      commit = "0744d001aa8470aaa53df28d32e5ceeb8af9bd70",
      importpath = "golang.org/x/net",
  )

  go_rules_dependencies()

would cause the go rules to use the specified version of x/net.

go_repository
~~~~~~~~~~~~~

Fetches a remote repository of a Go project, and generates ``BUILD.bazel`` files
if they are not already present. In vcs mode, it recognizes importpath redirection.

The :param:`importpath` must always be specified, it is used as the root import path
for libraries in the repository.

The repository should be fetched either using a VCS (:param:`commit` or :param:`tag`) or a source
archive (:param:`urls`).

In the future we expect this to be replaced by normal http_archive_ or git_repository_ rules,
once gazelle_ fully supports flat build files.

+--------------------------------+-----------------------------+-----------------------------------+
| **Name**                       | **Type**                    | **Default value**                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`name`                  | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| A unique name for this external dependency.                                                      |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`importpath`            | :type:`string`              | |mandatory|                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The root import path for libraries in the repository.                                            |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`commit`                | :type:`string`              | :value:`""`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The commit hash to checkout in the repository.                                                   |
|                                                                                                  |
| Exactly one of :param:`urls`, :param:`commit` or :param:`tag` must be specified.                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`tag`                   | :type:`string`              | :value:`""`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The tag to checkout in the repository.                                                           |
|                                                                                                  |
| Exactly one of :param:`urls`, :param:`commit` or :param:`tag` must be specified.                 |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`vcs`                   | :type:`string`              | :value:`""`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The version control system to use for fetching the repository.                                   |
| Useful for disabling importpath redirection if necessary.                                        |
|                                                                                                  |
| May be :value:`"git"`, :value:`"hg"`, :value:`"svn"`, or :value:`"bzr"`.                         |
|                                                                                                  |
| Only valid if :param:`remote` is set.                                                            |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`remote`                | :type:`string`              | :value:`""`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The URI of the target remote repository, if this cannot be determined from the value of          |
| :param:`importpath`.                                                                             |
|                                                                                                  |
| Only valid if one of :param:`commit` or :param:`tag` is set.                                     |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`urls`                  | :type:`string`              | :value:`None`                     |
+--------------------------------+-----------------------------+-----------------------------------+
| URLs for one or more source code archives.                                                       |
|                                                                                                  |
| Exactly one of :param:`urls`, :param:`commit` or :param:`tag` must be specified.                 |
|                                                                                                  |
| See http_archive_ for more details.                                                              |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`strip_prefix`          | :type:`string`              | :value:`""`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The internal path prefix to strip when the archive is extracted.                                 |
|                                                                                                  |
| Only valid if :param:`urls` is set.                                                              |
|                                                                                                  |
| See http_archive_ for more details.                                                              |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`type`                  | :type:`string`              | :value:`""`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The type of the archive, only needed if it cannot be inferred from the file extension.           |
|                                                                                                  |
| Only valid if :param:`urls` is set.                                                              |
|                                                                                                  |
| See http_archive_ for more details.                                                              |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`sha256`                | :type:`string`              | :value:`""`                       |
+--------------------------------+-----------------------------+-----------------------------------+
| The expected SHA-256 hash of the file downloaded.                                                |
|                                                                                                  |
| Only valid if :param:`urls` is set.                                                              |
|                                                                                                  |
| See http_archive_ for more details.                                                              |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`build_file_name`       | :type:`string`              | :value:`"BUILD.bazel,BUILD"`      |
+--------------------------------+-----------------------------+-----------------------------------+
| The name to use for the generated build files. Defaults to :value:`"BUILD.bazel"`.               |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`build_file_generation` | :type:`string`              | :value:`"auto"`                   |
+--------------------------------+-----------------------------+-----------------------------------+
| Used to force build file generation.                                                             |
|                                                                                                  |
| * :value:`"off"` : do not generate build files.                                                  |
| * :value:`"on"` : always run gazelle, even if build files are already present.                   |
| * :value:`"auto"` : run gazelle only if there is no root build file.                             |
+--------------------------------+-----------------------------+-----------------------------------+
| :param:`build_tags`            | :type:`string_list`         | :value:``                         |
+--------------------------------+-----------------------------+-----------------------------------+
| The set of tags to pass to gazelle when generating build files.                                  |
+--------------------------------+-----------------------------+-----------------------------------+

Example
^^^^^^^

The rule below fetches a repository with Git. Import path redirection is used
to automatically determine the true location of the repository.

.. code:: bzl

  load("@io_bazel_rules_go//go:def.bzl", "go_repository")

  go_repository(
      name = "org_golang_x_tools",
      importpath = "golang.org/x/tools",
      commit = "663269851cdddc898f963782f74ea574bcd5c814",
  )

The rule below fetches a repository archive with HTTP. GitHub provides HTTP
archives for all repositories. It's generally faster to fetch these than to
checkout a repository with Git, but the `strip_prefix` part can break if the
repository is renamed.

.. code:: bzl

  load("@io_bazel_rules_go//go:def.bzl", "go_repository")

  go_repository(
      name = "org_golang_x_tools",
      importpath = "golang.org/x/tools",
      urls = ["https://codeload.github.com/golang/tools/zip/663269851cdddc898f963782f74ea574bcd5c814"],
      strip_prefix = "tools-663269851cdddc898f963782f74ea574bcd5c814",
      type = "zip",
  )
