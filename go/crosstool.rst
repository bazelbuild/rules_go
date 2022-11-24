Configuring a custom C toolchain
================================

.. External links are here
.. _Configuring CROSSTOOL: https://docs.bazel.build/versions/0.23.0/tutorial/crosstool.html
.. _Understanding CROSSTOOL: https://docs.bazel.build/versions/0.23.0/crosstool-reference.html
.. _Configuring C++ toolchains: https://docs.bazel.build/versions/master/tutorial/cc-toolchain-config.html
.. _cc_library: https://docs.bazel.build/versions/master/be/c-cpp.html#cc_library
.. _crosstool_config.proto: https://github.com/bazelbuild/bazel/blob/master/src/main/protobuf/crosstool_config.proto
.. _go_binary: docs/go/core/rules.md#go_binary
.. _go_library: docs/go/core/rules.md#go_library
.. _toolchain: https://docs.bazel.build/versions/master/be/platform.html#toolchain
.. _#1642: https://github.com/bazelbuild/rules_go/issues/1642

References
----------

* `Configuring CROSSTOOL`_
* `Understanding CROSSTOOL`_
* `Configuring C++ toolchains`_

Introduction
------------

**WARNING:** This documentation is out of date. Some of the linked Bazel
documentation has been deleted in later versions, and there are a number of
TODOs. In particular, building and configuring a cross-compiling C++ toolchain
and testing it with cgo should be covered. `#1642`_ tracks progress on this.

The Go toolchain sometimes needs access to a working C/C++ toolchain in order to
produce binaries that contain cgo code or require external linking. rules_go
uses whatever C/C++ toolchain Bazel is configured to use. This means
`go_library`_ and `cc_library`_ rules can be linked into the same binary (via
the ``cdeps`` attribute in Go rules).

Bazel uses a CROSSTOOL file to configure the C/C++ toolchain, plus a few build
rules that declare constraints, dependencies, and file groups. By default, Bazel
will attempt to detect the toolchain installed on the host machine. This works
in most cases, but it's not hermetic (developers may have completely different
toolchains installed), and it doesn't always work with remote execution. It also
doesn't work with cross-compilation. Explicit configuration is required in these
situations.

This documented is intended to serve as a walk-through for configuring a custom
C/C++ toolchain for use with rules_go.

NOTE: The Go toolchain requires gcc, clang, or something that accepts the same
command-line arguments and produce the same error messages. MSVC is not
supported. This is a limitation of the Go toolchain, not rules_go. cgo infers
the types of C definitions based on the text of error messages.

TODO: Change the example to use a cross-compiling toolchain.

TODO: Add instructions for building a C compiler from scratch.

TODO: Build the standard C library and binutils for use with this toolchain.

Tutorial
--------

In this tutorial, we'll download a binary Clang release and install it into
a new workspace. This workspace can be uploaded into a new repository and
referenced from other Bazel workspaces.

You can find a copy of the example repository described here at
`https://github.com/jayconrod/bazel_cc_toolchains <https://github.com/jayconrod/bazel_cc_toolchains>`_.

Step 1: Create the repository
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Create a new repository and add a WORKSPACE file to the root directory. It
may be empty, but it's probably a good idea to give it a name.

.. code:: bash

  $ cat >WORKSPACE <<EOF
  workspace(name = "bazel_cc_toolchains")
  EOF

Step 2: Download a toolchain
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Download or compile a C toolchain, and install it in a subdirectory of your
workspace. I put it in ``tools``.

Note that this toolchain has Unixy subdirectories like ``bin``, ``lib``, and
``include``.

.. code:: bash

  $ curl http://releases.llvm.org/7.0.0/clang+llvm-7.0.0-x86_64-linux-gnu-ubuntu-16.04.tar.xz | tar xJ
  $ mv clang+llvm-7.0.0-x86_64-linux-gnu-ubuntu-16.04 tools
  $ ls tools
  bin  include  lib  libexec  share

Step 3: Write a CROSSTOOL
~~~~~~~~~~~~~~~~~~~~~~~~~

We'll create a file named ``tools/CROSSTOOL``, which describes our toolchain
to Bazel. If you have more than one C/C++ toolchain (e.g., different tools for
debug and optimized builds, or different compilers for different platforms),
they should all be configured in the same ``CROSSTOOL`` file.

The format for this file is defined in `crosstool_config.proto`_. Specifically,
CROSSTOOL should contain a ``CrosstoolRelease`` message, formatted as text.
Each ``toolchain`` field is a ``CToolchain`` message.

Here's a short example:

.. code:: proto

  major_version: "local"
  minor_version: ""

  toolchain {
    toolchain_identifier: "clang"
    host_system_name: "linux"
    target_system_name: "linux"
    target_cpu: "x86_64"
    target_libc: "x86_64"
    compiler: "clang"
    abi_version: "unknown"
    abi_libc_version: "unknown"

    tool_path { name: "ar" path: "bin/llvm-ar" }
    tool_path { name: "cpp" path: "bin/clang-cpp" }
    tool_path { name: "dwp" path: "bin/llvm-dwp" }
    tool_path { name: "gcc" path: "bin/clang" }
    tool_path { name: "gcov" path: "bin/llvm-profdata" }
    tool_path { name: "ld" path: "bin/ld.lld" }
    tool_path { name: "nm" path: "bin/llvm-nm" }
    tool_path { name: "objcopy" path: "bin/llvm-objcopy" }
    tool_path { name: "objdump" path: "bin/llvm-objdump" }
    tool_path { name: "strip" path: "bin/llvm-strip" }

    compiler_flag: "-no-canonical-prefixes"
    linker_flag: "-no-canonical-prefixes"

    compiler_flag: "-v"
    cxx_builtin_include_directory: "/usr/include"
  }

  default_toolchain {
    cpu: "x86_64"
    toolchain_identifier: "clang"
  }

For a more complete example, build any ``cc_binary`` with Bazel without
explicitly configuring ``CROSSTOOL``, then look at the ``CROSSTOOL`` that
Bazel generates for the automatically detected host toolchain. This can
be found in ``$(bazel info
output_base)/external/bazel_tools/tools/cpp/CROSSTOOL``. (You have to build
something with the host toolchain before this will show up).

Some notes:

* ``toolchain_identifier`` is the main name for the toolchain. You'll refer to
  it using this identifier from other messages and from build files.
* Most of the other fields at the top of ``toolchain`` are descriptive and
  can have any value.
* ``tool_path`` fields describe the various tools Bazel may invoke. The paths
  are relative to the directory that contains the ``CROSSTOOL`` file.
* ``compiler_flag`` and ``linker_flag`` are passed to the compiler and linker
  on each invocation, respectively.
* ``cxx_builtin_include_directory`` is a directory with include files that
  the compiler may read. Without this declaration, these files won't be
  visible in the sandbox. (TODO: make this hermetic).

Step 4: Write a build file
~~~~~~~~~~~~~~~~~~~~~~~~~~

We'll create a set of targets that will link the CROSSTOOL into Bazel's
toolchain system. It's likely this API will change in the future. This will be
in ``tools/BUILD.bazel``.

First, we'll create some ``filegroups`` that we can reference from other rules.

.. code:: bzl

  package(default_visibility = ["//visibility:public"])

  filegroup(
      name = "empty",
      srcs = [],
  )

  filegroup(
      name = "all",
      srcs = glob([
          "bin/*",
          "lib/**",
          "libexec/**",
          "share/**",
      ]),
  )

Next, we'll create a ``cc_toolchain`` target that tells Bazel where to find some
important files. This API is undocumented and will very likely change in the
future. We need to create one of these for each ``toolchain`` in ``CROSSTOOL``.
The ``toolchain_identifier`` and ``cpu`` fields should match, and the
filegroups should cover the files referenced in ``CROSSTOOL``.

.. code:: bzl

  cc_toolchain(
      name = "cc-compiler-clang",
      all_files = ":all",
      compiler_files = ":all",
      cpu = "x86_64",
      dwp_files = ":empty",
      dynamic_runtime_libs = [":empty"],
      linker_files = ":all",
      objcopy_files = ":empty",
      static_runtime_libs = [":empty"],
      strip_files = ":empty",
      supports_param_files = 1,
      toolchain_identifier = "clang",
  )

Finally, we'll create a ``cc_toolchain_suite`` target. This should reference
``cc_toolchain`` targets for all the toolchains in ``CROSSTOOL``. This API is
also undocumented and will probably change.

.. code:: bzl

  cc_toolchain_suite(
      name = "clang-toolchain",
      toolchains = {
          "x86_64": ":cc-compiler-clang",
          "x86_64|clang": ":cc-compiler-clang",
      },
  )

Step 5: Verify your toolchain works
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

At this point, you should be able to build a simple binary by passing a bunch
of extra flags to Bazel.

.. code:: bash

  $ mkdir example
  $ cat >example/hello.c <<EOF
  #include <stdio.h>

  int main() {
    printf("Hello, world!\n");
    return 0;
  }
  EOF

  $ cat >example/BUILD.bazel <<EOF
  cc_binary(
      name = "hello",
      srcs = ["hello.c"],
  )
  EOF

  $ bazel build \
    --crosstool_top=//tools:clang-toolchain \
    --cpu=x86_64 \
    --compiler=clang \
    --host_cpu=x86_64 \
    -s \
    //example:hello

You should see an invocation of ``tools/bin/clang`` in the output.

* ``--crosstool_top`` should be the label for the ``cc_toolchain_suite`` target
  defined earlier.
* ``--cpu=x86_64`` should be the ``cpu`` attribute in ``cc_toolchain`` and in
  the ``toolchain`` message in ``CROSSTOOL``.
* ``--compiler=clang`` should be the ``toolchain_identifier`` attribute in
  ``cc_toolchain`` and in the ``toolchain`` message in ``CROSSTOOL``.
* ``--host_cpu`` should be the same as ``--cpu``. If we were cross-compiling,
  it would be the ``cpu`` value for the execution platform (where actions are
  performed), not the host platform (where Bazel is invoked).
* ``-s`` prints commands.

Step 6: Configure a Go workspace to use the toolchain
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In the ``WORSKPACE`` file for your Go project, import the
``bazel_cc_toolchains`` repository. The way you do this may vary depending on
where you've put ``bazel_cc_toolchains``.

.. code:: bzl

  load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

  git_repository(
      name = "bazel_cc_toolchains",
      remote = "https://github.com/jayconrod/bazel_cc_toolchains",
      tag = "v1.0.0",
  )

Create a file named ``.bazelrc`` in the root directory of your Go project
(or add the code below to the end if already exists). Each line comprises a
Bazel command (such as ``build``), an optional configuration name (``clang``)
and a list of flags to be passed to Bazel when that configuration is used.
If the configuration is omitted, the flags will be passed by default.

.. code:: bash

  $ cat >>.bazelrc <<EOF
  build:clang --crosstool_top=@bazel_cc_toolchains//tools:clang-toolchain
  build:clang --cpu=x86_64
  build:clang --compiler=clang
  build:clang --host_cpu=x86_64
  EOF

You can build with ``bazel build --config=clang ...``.

Verify the toolchain is being used by compiling a "Hello world" cgo program.

.. code:: bash

  $ cat >hello.go <<EOF
  package main

  /*
  #include <stdio.h>

  void say_hello() {
    printf("Hello, world!\n");
  }
  */
  import "C"

  func main() {
    C.say_hello()
  }
  EOF

  $ cat >BUILD.bazel <<EOF
  load("@io_bazel_rules_go//go:def.bzl", "go_binary")

  go_binary(
      name = "hello",
      srcs = ["hello.go"],
      cgo = True,
  )

  $ bazel build --config=clang -s //:hello

You should see clang commands in Bazel's output.
