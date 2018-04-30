Go and proto builders
=====================

This directory contains a set of small programs for building pieces of Go
programs. These are used by Bazel during the execution phase instead of
Bash scripts, which are not portable and are prone to spacing and quoting
errors.

Most builders invoke programs in the Go toolchain. For example, ``compile.go``
invokes ``go tool compile``. Builders generally perform some extra actions
(for example, source filtering) before invoking the underlying tool.

Builder programs are constructed using a special rule, ``go_tool_binary``,
which breaks a cyclic dependency (``go_binary`` and other rules depend on
builders implicitly). This rule does not allow any library dependencies,
so all sources need to be compiled together in the ``main`` package.

Principles for writing builders
-------------------------------

* Builders that need to be directly available on the toolchain should be
  registered with the ``builder`` rule in ``go/private/rules/builders.bzl``.
  Special purpose builders like ``stdlib.go`` don't need to do this.
* Builders should have a package comment describing what the builder is for.
* ``log.SetFlags(0)`` should be called in ``main`` to avoid logging timestamps.
  ``log.SetPrefix`` should be called with the builder's mnemonic
  (e.g., ``GoCompile``).
* Builders should accept arguments in three forms:

  * Builder arguments (before ``--``) are interpreted directly by builders.
    These arguments may or may not be passed on to underlying tools.
  * Tool arguments (after ``--``) are passed on to underlying tools. Builders
    may add additional arguments before or after these.
  * Environment variables are passed on to underlying tools. Builders will
    usually not modify these.

* Arguments common to multiple builders (for example, ``-go``, ``-v``) should
  be handled in ``env.go``.
* Subcommands should be run through ``env.runGoCommand`` for uniform logging
  and error reporting.
