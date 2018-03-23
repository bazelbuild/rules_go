rules_go and Gazelle roadmap
============================

.. _Language Server Protocol: https://langserver.org/
.. _bazel-go-discuss: https://groups.google.com/forum/#!forum/bazel-go-discuss
.. _bazelbuild/bazel#1118: https://github.com/bazelbuild/bazel/issues/1118
.. _bazelbuild/bazel#4544: https://github.com/bazelbuild/bazel/issues/4544
.. _go/build: https://godoc.org/go/build
.. _open an issue: https://github.com/bazelbuild/rules_go/issues/new

This document describes the major rules_go and Gazelle features the Go team is
working on and how those features are prioritized. If you have an idea for a
feature which is not mentioned here or if you think something should be
prioritized differently, please send a message to bazel-go-discuss_, or `open an
issue`_.

Features here are prioritized as P0 (critical), P1 (important), and P2 (nice to
have). These priorities are not strict and may change over time. We may work on
simpler P2 features before more complicated P0 features.

Release process
---------------

P0: Release cadence
~~~~~~~~~~~~~~~~~~~

For most of the life of rules_go, we've kept a single master branch with
releases tagged on that branch. This practice has kept development simple and
fast, but it has imposed more migration work than necessary on developers that
just need a new Go SDK or bug fix.

In the future, the release cadence will be more regular. We will tag major
releases from ``master`` near the beginning of each month. Major releases will
include new features and upgraded versions of dependencies like gRPC. Of course,
dependencies may still be overridden in WORKSPACE. Major releases will have a
version number of the form 0.X.0 (where X is the major version number).

P0: Minor releases
~~~~~~~~~~~~~~~~~~

Additionally, we will tag minor releases when needed. Each major release will
mark the beginning of a *release branch*. We will cherry-pick fixes for severe
bugs and support for new Go SDK versions back to release branches. We will tag
minor releases from these branches. Minor releases will have a version number
of the form 0.X.Y (where Y is the minor version number).

Minor releases will not include changes to rules_go dependencies or changes
to the API: rules, attributes, and providers will not be changed or removed.

The last three release branches will be maintained, starting with 0.10. New
releases will be announced on `bazel-go-discuss`_.

Tools
-----

P0: Integration with tools
~~~~~~~~~~~~~~~~~~~~~~~~~~

Standalone tools such as gofmt, goimports, and govet typically assume a standard
Go project layout, i.e., that GOPATH and GOROOT are set and imported packages
may be found in the directories they point to. These assumptions are not
generally valid in a Bazel environment. Tools that collect build metadata with
`go/build`_ produce incomplete or inaccurate results since `go/build`_ does not
understand Bazel.

We are developing a new framework for collecting build metadata that will
decouple tools from the build system. This framework is important for both Bazel
and vgo, which will be the primary Go build system in future releases. Tools
using framework will be aware of generated code in Bazel workspaces.

P0: Integration with editors
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Editor and IDE support is vitally important. Features like code completion,
go-to-definition, and simple refactoring must work.

The build metadata framework described above is the key part of improving editor
support. We will also ensure there is a program that integrates this framework
with the `Language Server Protocol`_. This will provide Go-specific
functionality to most editors.

Dependency management
---------------------

P1: Better external repository support
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Gazelle will improve support for external repositories in several ways.

* Gazelle will index libraries in external repositories for dependency
  resolution. Currently, Gazelle relies on naming conventions when resolving
  dependencies in external repositories.
* Gazelle will be able to add and update repository rules, based on unresolved
  import paths from sources in the workspace. This will work for direct and
  transitive dependencies. This should simplify WORKSPACE file maintenance.
* Gazelle will import repository rules from more vendoring tools. Currently,
  Gazelle can import dependencies from dep using ``gazelle update-repos
  -from_file=Gopkg.lock``.

P1: Better vendoring support
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Gazelle will improve support for vendoring in several ways.

* Test rules will not be generated in vendor by default. Tests frequently pull
  in dependencies that aren't needed by libraries. Some vendoring tools, such as
  dep, already prune out test source files from vendored packages.
* It will be possible to configure Gazelle to ignore vendor directories in
  external repositories (via ``go_repository``).
* The ``importmap`` attribute will be set by default on go_library rules in
  vendor. This prevents conflicts when multiple packages with the same import
  path are linked.

P2: Overlay repositories
~~~~~~~~~~~~~~~~~~~~~~~~

The ``go_repository`` rule retrieves external repositories and generates build
files for them using Gazelle at build time. ``go_repository`` doesn't allow
manual modifications to generated build files, so if Gazelle does something
incorrectly, it's difficult to work around. This has especially been a problem
for protos.

In the future, Gazelle will support "overlay" repositories. Build files may be
generated ahead of time using a simple command, modified by hand if needed, then
checked in. Repositories may be retrieved using a variant of ``git_repository``
or ``http_archive`` that will copy the pre-generated build files into the
correct places.

Since ``go_repository`` works well for pure Go dependencies, we'll continue to
support it, and it will still be the default. However, we will move the
definition of ``go_repository`` to Gazelle's repository to reduce
coupling between rules_go and Gazelle.

Coverage
--------

P0: Bazel code coverage
~~~~~~~~~~~~~~~~~~~~~~~

``bazel coverage`` can be used instead of ``bazel test`` to gather coverage
information and present a unified report for multiple tests.

rules_go already has some support for coverage instrumentation: we can compile
binaries that generate coverage data. However, we need Bazel to be able to
collect coverage data and present it as a unified report. See
`bazelbuild/bazel#1118`_.

Build
-----

P1: Static analysis
~~~~~~~~~~~~~~~~~~~

Since 1.10, go test runs a subset of vet tests automatically when building
tests. We plan to support this and more. Users will be able to run a
configurable and extensible set of static analysis checks when building
libraries, binaries, and tests. Static analysis may be configured in three
places.

* A global set of checks for all Go packages, configured in WORKSPACE.
* A top-down set of checks for all packages a binary or test depends on,
  configured on the ``go_binary`` or ``go_test`` rule.
* A bottom-up set of checks for all packages that depend on a library,
  configured on the ``go_library`` rule.

By default, this framework will run the same safe subset of vet checks that go
test runs.

P2: Shared and plugin builds
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The Go toolchain builds static binaries by default, but it also supports
building shared libraries and plugins. rules_go should support these build modes
as well.

Protos
------

P1: Correct rules for vendored protos
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Bazel requires that .proto files import other .proto files using paths relative
to a repository root.  Unfortunately, this means there's no way for a .proto
file in a vendor directory to import another .proto file in a vendor directory.

The Bazel team is working on adding an attribute to proto_library rules that
allows setting a source root (see `bazelbuild/bazel#4544`_). When this attribute
is supported in a released version of Bazel, Gazelle will start generating
``proto_library`` rules that use it for proto files in vendor directories.

Note that by default, Gazelle does not generate proto rules in vendor
directories. This probably won't change.

P2: Remove old proto rules
~~~~~~~~~~~~~~~~~~~~~~~~~~

The new proto rules in ``//proto:def.bzl`` have been available for some time. At
some point, we'll remove ``//proto:go_proto_library.bzl`` so that we can drop
the additional dependencies it requires.

Rule naming and consolidation
-----------------------------

P1: Gazelle support for multiple packages per directory
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Gazelle supports a single Go package per directory, since that's what go build
supports. This is a painful limitation for protocol buffers: it's common to
store .proto files from different packages in the same directory. In the future,
Gazelle will generate separate ``proto_library`` and ``go_proto_library`` rules
per package.

Gazelle will also generate multiple ``go_library`` and ``go_test`` rules when
there are sources belonging to multiple packages in the same directory. It's
likely that we'll change the naming convention for libraries at this point (no
more ``go_default_library``).

P2: Consolidation of library, binary, and test rules
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``gazelle fix`` will squash rules in several new cases:

* In ``main`` packages with no tests, Gazelle will squash ``go_library`` rules
  into ``go_binary``.
* In packages that only have .proto source files (no .go files other than those
  generated by the proto compiler), gazelle will squash ``go_library`` rules
  into ``go_proto_library``.
* Internal and external test rules will be squashed into a single ``go_test``
  rule. rules_go can now build ``go_test`` rules with both internal and external
  sources, so separate rules are no longer necessary.
