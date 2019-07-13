Deprecation schedule
====================

.. _Gazelle: https://github.com/bazelbuild/bazel-gazelle
.. _gazelle fix: https://github.com/bazelbuild/bazel-gazelle#fix-command-transformations
.. _nogo: /go/nogo.rst
.. _officially supported: https://golang.org/doc/devel/release.html#policy
.. _proto rules: /proto/core.rst
.. _bazelbuild/bazel-bazelle#186: https://github.com/bazelbuild/bazel-gazelle/issues/186

This document lists public interfaces and features that are deprecated and will
be removed soon, as well as features that have already been removed. For each
item in this document, the deprecation rationale is listed, along with the last
supported rules_go release and the release when the functionality is scheduled
to be removed.

Deprecated features
-------------------

| **objc = True and related attributes**
| **Deprecated in:** 0.19.0
| **To be removed in:** 0.20.0
| **Rationale:** rules_go has been rewritten to build each Go package
  in a single action. This makes rules_go more efficient on remote
  configurations. Maintenance is considerably simpler. C, C++, Objective-C, and
  Objective-C++ files are compiled as part of this action, so ``objc = True``
  should no longer be necessary in most cases. In 0.19.0, this triggers
  a legacy path where .m and .mm files are built in an ``objc_library``.
  In 0.20.0, this legacy path and the ``objc_library`` target will be removed.
  Attributes specific to ``objc_library`` like ``module_map`` will no longer
  be accepted.
| **Migration:** Remove ``objc = True`` and attributes specific to
  ``objc_library`` from Go rules. If you need to embed Go code within a
  larger Objective C binary, build a ``go_binary`` with
  ``linkmode = "c-archive"``, then depend on the ``.cc`` target in the ``deps``
  attribute of a ``objc_library`` or similar rule. For example, if the
  ``go_binary`` is named ``"foo"``, you can add ``"foo.cc"`` to ``deps``.
|
| **Go 1.10**
| **Deprecated in:** 0.19.0
| **To be removed in:** 0.20.0
| **Rationale:** Go 1.10 is no longer `officially supported`_. Newer versions of
  the Go toolchain provide different feature sets, and it's difficult to
  support older versions at the same time.
| **Migration:** ``go_register_toolchains()`` automatically selects the newest
  version of Go unless a version is explicitly specified.

Removed features
----------------

| **Go 1.9**
| **Deprecated in:** 0.17.0
| **Removed in:** 0.18.0
| **Rationale:** Go 1.9 is no longer `officially supported`_. Newer versions of
  the Go toolchain provide different feature sets, and it's difficult to
  support older versions at the same time.
| **Migration:** ``go_register_toolchains()`` automatically selects the newest
  version of Go unless a version is explicitly specified.
|
| **go_vet_test rule**
| **Deprecated in:** 0.17.0
| **Removed in:** 0.18.0
| **Rationale:** `nogo`_ provides vet functionality, integrated into the build.
  The command ``go tool vet`` no longer works starting in Go 1.12, and
  ``go_vet_test`` will no longer work.
| **Migration:** Declare a ``nogo`` rule with ``vet = True``. Add it to the
  toolchain in the WORKSPACE call to ``go_register_toolchains``. See
  `nogo`_ for instructions.
|
| **Go 1.8**
| **Deprecated in:** 0.12.0
| **Removed in:** 0.13.0
| **Rationale:** Go 1.8 is no longer `officially supported`_. Newer versions of
  the Go toolchain provide options that let us streamline the compile and link
  process. The ``-importcfg`` option in particular will let us reduce
  symlinking before compiling.
| **Migration:** ``go_register_toolchains()`` automatically selects the newest
  version of Go unless a version is explicitly specified.
|
| **rules_go gazelle rule**
| **Deprecated in:** 0.13.0
| **Removed in:** 0.15.0
| **Rationale:** This lets us reduce coupling between rules_go and Gazelle.
  With this change, we should be able to remove the automatic dependency
  on ``@bazel_gazelle``.
| **Migration:** `gazelle fix`_ will change the load for the ``gazelle`` rule
  from ``@io_bazel_rules_go//go:def.bzl`` to ``@bazel_gazelle//:def.bzl``.
|
| **go_prefix**
| **Deprecated in:** 0.12.0
| **Removed in:** 0.13.0
| **Rationale:** Historically, the ``importpath`` of ``go_library`` was
  determined by its position in the repository relative to ``//:go_prefix``.
  This implicit dependency has made it difficult to support repositories where
  Go is not at the root of the tree. We have encouraged explicit ``importpath``
  attributes for several releases. ``go_prefix`` will be removed and
  ``importpath`` will be mandatory for ``go_library`` and ``go_proto_library``.
| **Migration:** Gazelle_ sets ``importpath`` automatically.
|
| **library attribute**
| **Deprecated in:** 0.9.0
| **Removed in:** 0.12.0
| **Rationale:** The ``library`` attribute in ``go_library``, ``go_binary``,
  and ``go_test`` was replaced with the ``embed`` attribute, which allows
  multiple libraries to be embedded instead of just one. We plan to remove
  ``library`` to simplify our implementation.
| **Migration:** Gazelle_ converts ``library`` to ``embed`` automatically.
|
| **linkstamp attribute**
| **Deprecated in:** 0.9.0
| **Removed in:** 0.12.0
| **Rationale:** The ``linkstamp`` has been made entirely redundant by 
  ``x_defs``, which allows multiple stamped variables in both ``go_binary``
  and ``go_library``.
| **Migration:** Requires a manual change. `gazelle fix`_ can't replace these,
  since it would require knowing which symbols will be stamped.
|
| **Legacy go_repository and new_go_repository**
| **Deprecated in:** 0.12.0
| **Removed in:** 0.13.0
| The ``go_repository`` rule has moved from ``@io_bazel_rules_go`` to
  ``@bazel_gazelle``. Gazelle is a core part of ``go_repository``, and moving
  ``go_repository`` to that repository allows us to reduce rules_go's
  dependence on Gazelle.
| **Migration:** `gazelle fix`_ automatically updates WORKSPACE files to use
  the new ``go_repository``.
|
| **go_sdk and go_repositories repository rules**
| **Deprecated in:** 0.7.0
| **Removed in:** 0.12.0
| **Rationale:** ``go_sdk`` is redundant with the ``go_host_sdk_``,
  ``go_download_sdk``, and ``go_local_sdk`` rules. ``go_repositories`` should
  not be used anymore; ``go_rules_dependencies`` and ``go_register_toolchains``
  should be called instead.
| **Migration:** Requires a manual change to WORKSPACE.
|
| **cgo_library and cgo_genrule**
| **Deprecated in:** 0.5.3
| **Removed in:** 0.12.0
| **Rationale:** These rules are redundant with ``go_library`` with
  ``cgo = True``.
| **Migration:** `gazelle fix`_ automatically squashes or renames
  ``cgo_library`` rules with ``go_library``.
|
| **Legacy go_proto_library.bzl**
| **Deprecated in:** 0.9.0
| **Removed in:** 0.12.0
| **Rationale:** We have a new set of `proto rules`_ in
  ``@io_bazel_rules_go//proto:def.bzl``. There's no need to preserve the rules
  in ``go_proto_library.bzl``.
| **Migration:** Gazelle generates new proto rules automatically when run with
  ``-proto=default`` or ``# gazelle:proto default``.
