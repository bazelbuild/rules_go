Go build-time code analysis
===========================

.. _go_checker: core.rst#go_checker
.. _go_library: core.rst#go_library
.. _go_tool_library: core.rst#go_tool_library
.. _analysis: tools/analysis/analysis.go
.. _GoLibrary: providers.rst#GoLibrary
.. _GoSource: providers.rst#GoSource
.. _GoArchive: providers.rst#GoArchive

.. role:: param(kbd)
.. role:: type(emphasis)
.. role:: value(code)
.. |mandatory| replace:: **mandatory value**

**WARNING**: This functionality is experimental, so its API might change.
Please do not rely on it for production use, but feel free to use it and file
issues.

rules_go allows you to define custom source-code-level checks that are executed
alongside the Go compiler. These checks print error messages by default, but can
be configured to also fail compilation. Checks can be used to catch bug and
anti-patterns early in the development process.

**TODO**: make vet run by default.

.. contents:: :depth: 2

-----

Overview
--------

Writing and registering checks
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Checks are Go packages are register themselves with package `analysis`_.
Each check is invoked once per Go package, and is provided the abstract
syntax trees (ASTs) and type information for that package. For example:

.. code:: go

    // package importunsafe checks whether a Go package imports package unsafe.
    package importunsafe

    import (
      "strconv"

      "github.com/bazelbuild/rules_go/go/tools/analysis"
    )

    var Analysis = &analysis.Analysis{Name: "importunsafe", Run: run}

    func init() {
      analysis.Register(Analysis)
    }

    func run(p *analysis.Package) (*analysis.Result, error) {
      var findings []*analysis.Finding
      for _, f := range p.Files {
        for _, imp := range f.Imports {
          path, err := strconv.Unquote(imp.Path.Value)
          if err == nil && path == "unsafe" {
            findings = append(findings, &analysis.Finding{
              Pos:     n.Pos(),
              End:     n.End(),
              Message: "package unsafe must not be imported",
            })
          }
        }
      }
      return &analysis.Result{Findings: findings}, nil
    }

Each check must be written as a `go_tool_library`_ rule. This rule
is identical to `go_library`_ but avoids a bootstrapping problem, which
we will explain later. For example:

.. code:: bzl

    load("@io_bazel_rules_go//go:def.bzl", "go_tool_library")

    go_tool_library(
        name = "importunsafe",
        srcs = ["importunsafe.go"],
        importpath = "importunsafe",
        deps = ["@io_bazel_rules_go//go/tools/analysis:analysis"],
        visibility = ["//visibility:public"],
    )

    go_tool_library(
        name = "unsafedom",
        srcs = [
            "check_dom.go",
            "dom_utils.go",
        ],
        importpath = "unsafedom",
        deps = ["@io_bazel_rules_go//go/tools/analysis:analysis"],
        visibility = ["//visibility:public"],
    )

`go_checker`_ generates a checker program that is run alongside the compiler
to analyze Go source code. You must define a `go_checker`_ target whose ``deps``
attribute contains all check targets. These checks will be linked to the
generated check binary and executed at build-time.

.. code:: bzl

    load("@io_bazel_rules_go//go:def.bzl", "go_checker")

    go_checker(
        name = "my_checker",
        deps = [
            ":importunsafe",
            ":unsafedom",
            "@javascript_checks//:loopclosure", # we can import checks from a remote repo
        ],
        visibility = ["//visibility:public"],
    )

**NOTE**: Writing each check as a `go_tool_library`_ rule instead of a
`go_library`_ rule avoids a circular dependency: `go_library`_ implicitly
depends on `go_checker`_, which depends on check libraries, which must not
depend on `go_checker`_. `go_tool_library`_ does not have the same implicit
dependency.

Finally, the `go_checker`_ target must be passed to ``go_register_toolchains``
in your ``WORKSPACE`` file.

.. code:: bzl

    load("@io_bazel_rules_go//go:def.bzl", "go_rules_dependencies", "go_register_toolchains")
    go_rules_dependencies()
    go_register_toolchains(checker="@//:my_checker")

The generated checker will run when building any Go target (e.g. `go_library`_)
within your workspace, even if the target is imported from an external
repository. However, the checker will not run when targets from the current
repository are imported into other workspaces and built there.

Configuring checks
~~~~~~~~~~~~~~~~~~

By default, checks print their findings but do not interrupt compilation. This
default behavior can be overridden with a JSON configuration file.

The top-level JSON object in the file must be keyed by the name of the check
being configured. These names must match the Analysis.Name of the registered
analysis package. The JSON object's values are themselves objects which may
contain the following key-value pairs:

+----------------------------+---------------------------------------------------------------------+
| **Key**                    | **Type**                                                            |
+----------------------------+---------------------------------------------------------------------+
| ``"description"``          | :type:`string`                                                      |
+----------------------------+---------------------------------------------------------------------+
| Description of this check configuration.                                                         |
+----------------------------+---------------------------------------------------------------------+
| ``"severity"``             | :type:`string`                                                      |
+----------------------------+---------------------------------------------------------------------+
| Determines the actions taken when a check violation is found. It must take on one of the         |
| following values:                                                                                |
|                                                                                                  |
| - ``"WARNING"`` : warning message emitted at compile-time                                        |
| - ``"ERROR"``   : fails compilation in addition to emitting an error message                     |
+----------------------------+---------------------------------------------------------------------+
| ``"apply_to"``             | :type:`dictionary, string to string`                                |
+----------------------------+---------------------------------------------------------------------+
| Specifies files that this check will exclusively apply to.                                       |
| Its keys are regular expression strings matching Go files, and its values are strings containing |
| a description of the entry.                                                                      |
+----------------------------+---------------------------------------------------------------------+
| ``"whitelist"``            | :type:`dictionary`                                                  |
+----------------------------+---------------------------------------------------------------------+
| Specifies files that are exempt from this check.                                                 |
| Its keys and values are strings that have the same semantics as those in `apply_to`.             |
| Keys in whitelist override keys in apply_to. If a .go file matches both an `apply_to` and        |
| `whitelist` key, the check will not apply to that file.                                          |
+----------------------------+---------------------------------------------------------------------+

Example
^^^^^^^

The following configuration file configures the checks named ``importunsafe``,
``unsafedom``, and ``loopclosure``.

.. code:: json

    {
      "importunsafe": {
        "severity": "ERROR",
        "whitelist": {
          "src/foo.go": "manually verified that behavior is working-as-intended",
          "src/bar.go": "see issue #1337"
        }
      },
      "unsafedom": {
        "severity": "WARNING",
        "apply_to": {
          "src/js/*": ""
        },
        "whitelist": {
          "src/(third_party|vendor)/*": "enforce DOM safety requirements only on first-party code"
        }
      },
      "loopclosure": {
        "description": "fail builds without exception since we know this check is 100% accurate",
        "severity": "ERROR"
      }
    }

This label referencing this configuration file must be provided as the
``config`` attribute value of the ``go_checker`` rule.

.. code:: bzl

    go_checker(
        name = "my_checker",
        deps = [
            ":importunsafe",
            ":unsafedom",
            "@javascript_checks//:loopclosure",
        ],
        config = "config.json"
        visibility = ["//visibility:public"],
    )

API
---

go_checker
~~~~~~~~~~

This generates a checker program that is run alongside the compiler to analyze
Go source code.

Attributes
^^^^^^^^^^

+----------------------------+-----------------------------+---------------------------------------+
| **Name**                   | **Type**                    | **Default value**                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`name`              | :type:`string`              | |mandatory|                           |
+----------------------------+-----------------------------+---------------------------------------+
| A unique name for this rule.                                                                     |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`deps`              | :type:`label_list`          | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| List of Go libraries that will be linked to the generated checker binary.                        |
| These libraries must call ``analysis.Register`` to ensure that the analyses they implement are   |
| called by the checker binary.                                                                    |
| These libraries must be `go_tool_library`_ targets to avoid bootstrapping problems.              |
+----------------------------+-----------------------------+---------------------------------------+
| :param:`config`            | :type:`label`               | :value:`None`                         |
+----------------------------+-----------------------------+---------------------------------------+
| JSON configuration file that configures one or more of the checks in `deps`.                     |
+----------------------------+-----------------------------+---------------------------------------+

Example
^^^^^^^

.. code:: bzl

    go_checker(
        name = "my_checker",
        deps = [
            ":importunsafe",
            ":othercheck",
            "@javascript_checks//:unsafedom", # we can import checks from a remote repo
        ],
        config = ":config.json"
        visibility = ["//visibility:public"],
    )
