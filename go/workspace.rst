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
.. _normal go logic: https://golang.org/cmd/go/#hdr-Remote_import_paths
.. _gazelle: tools/gazelle/README.md
.. _http_archive: https://docs.bazel.build/versions/master/be/workspace.html#http_archive
.. _git_repository: https://docs.bazel.build/versions/master/be/workspace.html#git_repository
.. _nested workspaces: https://bazel.build/designs/2016/09/19/recursive-ws-parsing.html

.. _go_prefix_faq: /README.rst#whats-up-with-the-go_default_library-name
.. |go_prefix_faq| replace:: FAQ

.. role:: param(kbd)
.. role:: type(emphasis)
.. role:: value(code)
.. |mandatory| replace:: **mandatory value**

Workspace rules are either repository rules, or macros that are intended to be used from the
WORKSPACE file.

`Toolchain support <toolchains>`_:
    This is both the functions to add the normal go toolchains (go_register_toolchains_) and the
    ones to declare your own toolchains (go_sdk_ and go_toolchain_).
    These are here for the long term, and are documented in the toolchains_ documentation.

go_rules_dependencies_:
    This is invoked to add the things that the go rules depend on to your workspace.
    We expect this to be replaced by a Bazel feature (`nested workspaces`_) in the long term.

go_repository_:
    This is used to automatically generate build files for a go repository that you depend on.
    In the future we expect this to be replaced by normal http_archive_ or git_repository_ rules,
    once gazelle_ fully supports flat build files.
    There is also the deprecated new_go_repository_ which you should no longer use (we will be
    deleting it soon).

go_prefix_:
    This is a legacy from when the import path for a go_library_ was determined from the root
    go_prefix and the path from the workspace root. Now instead we have every single go_library_
    know it's own import path. We currently maintain this rule for backwards compatability, but we
    expect to have it removed well before 1.0

-----

go_rules_dependencies
~~~~~~~~~~~~~~~~~~~~~

Adds Go-related external dependencies to the WORKSPACE, including the Go
toolchain and standard library. All the other workspace rules and build rules
assume that this rule is placed in the WORKSPACE.

When `nested workspaces`_  arrive this will be redundant, but for nowyou should **always** call this macro from your WORKSPACE.

It only adds repositories that have not previously been declared, so you can override anything it
does by adding that repository **before** calling this macro, which is why we recommend you should
put the call at the bottom of your WORKSPACE.

The macro takes no arguments and returns no results. You put

.. code::

  go_rules_dependencies()

in the bottom of your WORKSPACE file and forget about it.


The list of dependancies it adds is quite long, there are a few listed below that you are more
likely to want to know about and override, but it is by no means a complete list.

* :value:`com_google_protobuf` : An http_archive for `github.com/google/protobuf`_
* :value:`com_github_golang_protobuf` : A go_repository for `github.com/golang/protobuf`_
* :value:`org_golang_google_grpc` : A go_repository for `google.golang.org/grpc`_
* :value:`org_golang_x_net` : A go_repository for `golang.org/x/net`_
* :value:`org_golang_x_tools` : A go_repository for `golang.org/x/tools`_

go_repository
~~~~~~~~~~~~~

Fetches a remote repository of a Go project, and generates ``BUILD.bazel`` files
if they are not already present. In vcs mode, it recognizes importpath redirection.

The :param:`importpath` must always be specified, it is used as the root import path
for libraries in the repository.

The repository should be fetched either using a VCS (:param:`commit` or :param:`tag`) or a source
archive (:param:`urls`).

+----------------------------+-----------------------------+---------------------------------------+
| **Name**                   | **Type**                    | **Default value**                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`name`              | :type:`string`              | |mandatory|                           |
+----------------------------+-----------------------------+---------------------------------------+
| A unique name for this external dependency.                                                      |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`importpath`        | :type:`string`              | |mandatory|                           |
+----------------------------+-----------------------------+---------------------------------------+
| The root import path for libraries in the repository.                                            |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`commit`            | :type:`string`              | :value:`""`                           |
+----------------------------+-----------------------------+---------------------------------------+
| The commit hash to checkout in the repository.                                                   |
|                                                                                                  |
| Exactly one of :param:`urls`, :param:`commit` or :param:`tag` must be specified.                 |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`tag`               | :type:`string`              | :value:`""`                           |
+----------------------------+-----------------------------+---------------------------------------+
| The tag to checkout in the repository.                                                           |
|                                                                                                  |
| Exactly one of :param:`urls`, :param:`commit` or :param:`tag` must be specified.                 |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`vcs`               | :type:`string`              | :value:`""`                           |
+----------------------------+-----------------------------+---------------------------------------+
| The version control system to use for fetching the repository.                                   |
| Useful for disabling importpath redirection if necessary.                                        |
|                                                                                                  |
| May be :value:`"git"`, :value:`"hg"`, :value:`"svn"`, or :value:`"bzr"`.                         |
|                                                                                                  |
| Only valid if :param:`remote` is set.                                                            |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`remote`            | :type:`string`              | :value:`""`                           |
+----------------------------+-----------------------------+---------------------------------------+
| The URI of the target remote repository, if this cannot be determined from the value of          |
| :param:`importpath`.                                                                             |
|                                                                                                  |
| Only valid if one of :param:`commit` or :param:`tag` is set.                                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`urls`              | :type:`string`              | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| URLs for one or more source code archives.                                                       |
|                                                                                                  |
| Exactly one of :param:`urls`, :param:`commit` or :param:`tag` must be specified.                 |
|                                                                                                  |
| See http_archive_ for more details.                                                              |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`strip_prefix`      | :type:`string`              | :value:`""`                           |
+----------------------------+-----------------------------+---------------------------------------+
| The internal path prefix to strip when the archive is extracted.                                 |
|                                                                                                  |
| Only valid if :param:`urls` is set.                                                              |
|                                                                                                  |
| See http_archive_ for more details.                                                              |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`type`              | :type:`string`              | :value:`""`                           |
+----------------------------+-----------------------------+---------------------------------------+
| The type of the archive, only needed if it cannot be inferred from the file extension.           |
|                                                                                                  |
| Only valid if :param:`urls` is set.                                                              |
|                                                                                                  |
| See http_archive_ for more details.                                                              |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`sha256`            | :type:`string`              | :value:`""`                           |
+----------------------------+-----------------------------+---------------------------------------+
| The expected SHA-256 hash of the file downloaded.                                                |
|                                                                                                  |
| Only valid if :param:`urls` is set.                                                              |
|                                                                                                  |
| See http_archive_ for more details.                                                              |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`build_file_name`   | :type:`string`              | :value:`"BUILD.bazel,BUILD"`          |
+----------------------------+-----------------------------+---------------------------------------+
| The name to use for the generated build files. Defaults to :value:`"BUILD.bazel"`.               |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`                   | :type:`string`              | :value:`"auto"`                       |
| build_file_generation`     |                             |                                       |
+----------------------------+-----------------------------+---------------------------------------+
| Used to force build file generation.                                                             |
|                                                                                                  |
| * :value:`"off"` : do not generate build files.                                                  |
| * :value:`"on"` : always run gazelle, even if build files are already present.                   |
| * :value:`"auto"` : run gazelle only if there is no root build file.                             |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`build_tags`        | :type:`string_list`         | :value:``                             |
+----------------------------+-----------------------------+---------------------------------------+
| The set of tags to pass to gazelle when generating build files.                                  |
+----------------------------+-----------------------------+---------------------------------------+

go_prefix
~~~~~~~~~

Set the :param:`importpath` attribute on all rules instead of using `go_prefix`.
See #721.

This declares the common prefix of the import path which is shared by all Go libraries in the
repository.
A go_prefix rule must be declared in the top-level BUILD file for any repository containing
Go rules.
This is used by the Bazel rules during compilation to map import paths to dependencies.
See the |go_prefix_faq|_ for more information.

+----------------------------+-----------------------------+---------------------------------------+
| **Name**                   | **Type**                    | **Default value**                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`prefix`            | :type:`string`              | |mandatory|                           |
+----------------------------+-----------------------------+---------------------------------------+
| Global prefix used to fully qualify all Go targets.                                              |
+----------------------------+-----------------------------+---------------------------------------+
