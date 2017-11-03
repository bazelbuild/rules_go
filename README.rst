Go rules for Bazel_
=====================

.. All external links are here
.. _Bazel: https://bazel.build/
.. |travis| image:: https://travis-ci.org/bazelbuild/rules_go.svg?branch=master
  :target: https://travis-ci.org/bazelbuild/rules_go
.. |jenkins| image:: http://ci.bazel.io/buildStatus/icon?job=PR/rules_go
  :target: http://ci.bazel.io/view/Bazel%20bootstrap%20and%20maintenance/job/PR/job/rules_go/
.. _gazelle: go/tools/gazelle/README.rst
.. _vendoring: Vendoring.md
.. _protocol buffers: proto/core.rst
.. _go_repository: go/workspace.rst#go_repository
.. _go_library: go/core.rst#go_library
.. _go_binary: go/core.rst#go_binary
.. _go_test: go/core.rst#go_test
.. _bazel-go-discuss: https://groups.google.com/forum/#!forum/bazel-go-discuss
.. _Bazel labels: https://docs.bazel.build/versions/master/build-ref.html#labels
.. _#265: https://github.com/bazelbuild/rules_go/issues/265
.. _#721: https://github.com/bazelbuild/rules_go/issues/721
.. _#889: https://github.com/bazelbuild/rules_go/issues/889

.. ;; And now we continue with the actual content

======== =========
Travis   Jenkins
======== =========
|travis| |jenkins|
======== =========

Announcements
-------------

November 3, 2017
  Release `0.7.0 <https://github.com/bazelbuild/rules_go/releases/tag/0.7.0>`_
  is now available.
October 16, 2017
  We have a new mailing list: `bazel-go-discuss`_. All questions about building
  Go with Bazel and using Gazelle are welcome.
October 10, 2017
  We have bumped the minimum Bazel version to 0.6.0 due to `#889`_.
October 9, 2017
  Release `0.6.0 <https://github.com/bazelbuild/rules_go/releases/tag/0.6.0>`_
  is now available. Bazel 0.5.4 or later is now required. The WORKSPACE
  boilerplate has also changed (see Setup_).


.. contents::


Quick links
-----------

* Mailing list: `bazel-go-discuss`_
* `Core api <go/core.rst>`_
* `Workspace rules <go/workspace.rst>`_
* `Toolchains <go/toolchains.rst>`_
* `Protobuf rules <proto/core.rst>`_
* `Extra rules <go/extras.rst>`_
* `Deprecated rules <go/deprecated.rst>`_
* `Build modes <go/modes.rst>`_


Overview
--------

The rules are in the alpha stage of development. They support:

* `libraries <go_library_>`_
* `binaries <go_binary_>`_
* `tests <go_test_>`_
* vendoring_
* cgo
* cross compilation
* auto generating BUILD files via gazelle_
* `protocol buffers`_

They currently do not support (in order of importance):

* bazel-style auto generating BUILD (where the library name is other than
  go_default_library)
* C/C++ interoperation except cgo (swig etc.)
* coverage
* test sharding

:Note: The latest version of these rules (0.7.0) require Bazel ≥ 0.6.0 to
  work.

The ``master`` branch is only guaranteed to work with the latest version of Bazel.


Setup
-----

* Create a file at the top of your repository named `WORKSPACE` and add one
  of the snippets below, verbatim. This will let Bazel fetch necessary
  dependencies from this repository and a few others.

  If you want to use the latest stable release, add the following:

  .. code:: bzl

    http_archive(
        name = "io_bazel_rules_go",
        url = "https://github.com/bazelbuild/rules_go/releases/download/0.7.0/rules_go-0.7.0.tar.gz",
        sha256 = "91fca9cf860a1476abdc185a5f675b641b60d3acf0596679a27b580af60bf19c",
    )
    load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependencies", "go_register_toolchains")
    go_rules_dependencies()
    go_register_toolchains()

  If you want to use a specific commit (for example, something close to
  ``master``), add the following instead:

  .. code:: bzl

    git_repository(
        name = "io_bazel_rules_go",
        remote = "https://github.com/bazelbuild/rules_go.git",
        commit = "a390e7f7eac912f6e67dc54acf67aa974d05f9c3",
    )
    load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependencies", "go_register_toolchains")
    go_rules_dependencies()
    go_register_toolchains()

  If you plan to use the proto rules (``go_proto_library`` and
  ``go_grpc_library``), add the following to WORKSPACE.

  .. code:: bzl

    load("@io_bazel_rules_go//proto:def.bzl", "proto_register_toolchains")
    proto_register_toolchains()

  You can add more external dependencies to this file later (see go_repository_).

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
build files automatically using gazelle_, a tool included in this repository.

* Add the code below to the ``BUILD.bazel`` file in your repository's
  root directory. Replace the ``prefix`` string with the prefix you chose for
  your project earlier.

  .. code:: bzl

    load("@io_bazel_rules_go//go:def.bzl", "gazelle")

    gazelle(
        name = "gazelle",
        prefix = "github.com/example/project",
    )

* If your project uses vendoring, add ``external = "vendored",`` below the
  ``prefix`` line.

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
        library = ":go_default_library",
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
        importpath = "github.com/example/project/foo",
    )

* For instructions on how to depend on external libraries,
  see _vendoring

FAQ
---

Can I still use the ``go`` tool?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Yes, this setup was deliberately chosen to be compatible with ``go build``.
Make sure your project appears in ``GOPATH``, and it should work.

Note that ``go build`` won't be aware of dependencies listed in ``WORKSPACE``, so
these will be downloaded into ``GOPATH``. You may also need to check in generated
files.

What's up with the ``go_default_library`` name?
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This was used to keep import paths consistent in libraries that can be built
with ``go build`` before the ``importpath`` attribute was available.

In order to compile and link correctly, the Go rules need to be able to
translate Bazel labels to Go import paths. Libraries that don't set the
``importpath`` attribute explicitly have an implicit dependency on ``//:go_prefix``,
a special rule that specifies an import path prefix. The import path is
the prefix concatenated with the Bazel package and target name. For example,
if your prefix was ``github.com/example/project``, and your library was
``//foo/bar:bar``, the Go rules would decide the import path was
``github.com/example/project/foo/bar/bar``. The stutter at the end is incompatible
with ``go build``, so if the label name is ``go_default_library``, the import path
is just the prefix concatenated with the package name. So if your library is
``//foo/bar:go_default_library``, the import path is
``github.com/example/project/foo/bar``.

We are working on deprecating ``go_prefix`` and making ``importpath`` mandatory (see
`#721`_). When this work is   complete, the ``go_default_library`` name won't be needed.
We may decide to stop using this name in the future (see `#265`_).

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
