Cross-compilation support in rules_go
=====================================

## Objective

Provide support in rules_go for generating binary artifacts targeted
to a different os/architecture than the host.

## Use cases

1. Generating go artifacts for distribution in external archives
  targeted for a specific platform.

2. Generating go artifacts for inclusion into docker images via the
  `docker_build` rule.

## Proposal

The ideal scenario would:

* Not require additional end-user rules, i.e. `go_binary` should work
  for this purpose.

* Allow the user to generate a cross-compiled go binary artifact
  without modification of the `BUILD` file containing the `go_binary`
  rule (use case #1).  This would likely work in concert with the
  `--cpu` and/or `--crosstool_top` option.

* Allow the user to explicity state the target architecture in the
  `go_binary` rule, when the target architecture is a fixed/known
  constant along a multistep build path (use case #2).

## Implementation plan

* Implement capture of absolute path of the go toolchain during
  toolchain configuration (via the `go_root` rule).  For reasons
  inherent to go itself, cross-compilation does not seem to work when
  invoked via a non-absolute path (see
  https://github.com/golang/go/issues/17017).

* In `def.bzl`, `GOOS` and `GOARCH` are already included in the
  environment of ctx.actions.  Add `GOROOT` into that dict, and change
  all invocations of `go tool CMD` to use `$GOROOT/bin/go` rather than
  `('../' * out_depth) + ctx.file.go_tool.path`.

* Add a non-mandatory string attribute `os_arch` to the go_binary
  rule.  The allowed values are enumerated in
  https://github.com/pubref/rules_go/blob/xgo-binary/go/private/goos_goarch.bzl.

* Implement an aspect that propogates along the dependencies of
  go_binary.  The aspect implementation will be responsible for
  generating cross-compiled libraries for the target architecture and
  parameterized by the `os_arch` attribute (or inferred from the
  `--cpu` value).

* Refactor `_go_library_impl` and related `emit_` that lead to `go
  tool` invocations to be agnostic to the layout of the `ctx`
  argument, to be callable either from a normal rule context or aspect
  rule context.  The current implementation makes some assumptions
  about the structure of the `ctx` argument.  For example, `ctx.attr`
  vs `ctx.rule.attr`.

* Change the output location of a cross-compiled go_library/binary. In
  order for generated artifacts not to collide under `bazel-bin/`,
  artifacts would be generated in an `os_arch` subdirectory.  This is
  analogous to how `go` itself works, placing the cross-compiled
  stdlib in `pkg/$GOOS_$GOARCH/`.

* Add a `go install std` command with `go tool compile` to
  cross-compile the standard library, if needed.

* Add tests that demonstrate it's use.

## Questions

* It's still a bit muddy as to how `--cpu`, `--compiler`, and
  `--crosstool_top` actually work here.  Will the user have to supply
  their own `--crosstool_top`?  Will the default one(s) in the main
  bazel repo be sufficient?  Will a `CROSSTOOL` file need to be
  included in the rules_go repository?

* Bazel command line options include the `--aspects
  path/to/aspect.bzl` option.  Thus far this option is predominantly
  used for IDE support.  Should this be part of the equation?

## Prototype

A functioning initial prototype is demonstrated in the
https://github.com/pubref/rules_go/tree/xgo-binary branch (which does
not necessarily adhere to all parts of this document), intended to be
re-implemented in smaller units roughly according to this design
document.
