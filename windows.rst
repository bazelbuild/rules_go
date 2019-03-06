Using rules_go on Windows
=========================

This is a list of notes from the last time I ran rules_go on Windows. This
is not complete documentation yet, but will be expanded some time in the
future. Bazel's support for Windows is changing and improving over time, so
these instructions may be out of date.

Preparation
-----------

These steps are completely optional.

* Consider disabling Windows Defender, at least temporarily. Defender will
  block the Bazel download for 20+ minutes, presumably because
  some signature is not in place. This can be done in Windows Defender
  Security Center > App & Browser control > Check apps and files: Off.
* Install VSCode. It has pretty good support for Go and a good terminal
  emulator.

Install and configure dependencies
----------------------------------

* Install msys2 from https://www.msys2.org/. This is needed to provide a bash
  environment for Bazel.

  * Follow the installation directions to the end, including
    running ``pacman -Syu`` and ``pacman -Su`` in the msys2 shell.

* Install additional msys2 tools.

  * Run ``pacman -S mingw-w64-x86_64-gcc``. GCC is needed if you plan to build
    any cgo code. MSVC will not work with cgo. This is a Go limitation, not a
    Bazel limitation. cgo determines types of definitions by compiling specially
    crafted C files and parsing error messages. GCC or clang are specifically
    needed for this.
  * Run ``pacman -S patch``. ``patch`` is needed by ``git_repository`` and
    ``http_archive`` dependencies declared by rules_go. We use it to add
    and modify build files.

* Add ``C:\msys64\usr\bin`` to ``PATH`` in order to locate ``patch`` and
  other DLLs.
* Add ``C:\msys64\mingw64\bin`` to ``PATH`` in order to locate mingw DLLs.
  ``protoc`` and other host binaries will not run without these.
* Set the environment variable ``BAZEL_SH`` to ``C:\msys64\usr\bin\bash.exe``.
  Bazel needs this to run shell scripts.
* Set the environment variable ``CC`` to ``C:\msys64\mingw64\bin\gcc.exe``.
  Bazel uses this to configure the C/C++ toolchain.
* Install the MSVC++ redistributable from
  https://www.microsoft.com/en-us/download/details.aspx?id=48145.
  Bazel itself depends on this.
* Install Git from https://git-scm.com/download/win. The Git install should
  add the installed directory to your ``PATH`` automatically.

Install bazel
-------------

* Download Bazel from https://github.com/bazelbuild/bazel/releases.
* Move the binary to ``%APPDATA%\bin\bazel.exe``.
* Add that directory to ``PATH``.
* Confirm ``bazel version`` works.
* Confirm you can run a C binary with
  ``bazel run --cpu=x64_windows --compiler=mingw-gcc //:target``.

Confirm Go works
----------------

* Copy boilerplate from rules_go.
* Confirm that you can run a pure Go "hello world" binary with
  ``bazel run //:target``
* Confirm you can run a cgo binary with
  ``bazel run --cpu=x64_windows --compiler=mingw-gcc //:target``
* You may want to add ``build --cpu=x64_windows --compiler=mingw-gcc`` to
  a ``.bazelrc`` file in your project or in your home directory.
