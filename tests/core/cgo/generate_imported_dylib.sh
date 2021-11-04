#!/usr/bin/env bash

set -exo pipefail

cd "$(dirname "$0")"

case "$(uname -s)" in
  Linux*)
    cc -shared -o libimported.so imported.c
    cc -shared -o libversioned.so.2 imported.c
    ;;
  Darwin*)
    cc -shared -Wl,-install_name,@rpath/libimported.dylib -o libimported.dylib imported.c
    # Oracle Instant Client was distributed as libclntsh.dylib.12.1 (https://www.oracle.com/database/technologies/instant-client/macos-intel-x86-downloads.html),
    # even though the standard name should be libclntsh.12.1.dylib, according to
    # "Mac OS X For Unix Geeks", 4th Edition, Chapter 11
    cc -shared -Wl,-install_name,@rpath/libversioned.dylib.2 -o libversioned.dylib.2 imported.c
    # We need a symlink to load dylib on Darwin
    ln -s libversioned.dylib.2 libversioned.dylib
    ;;
  *)
    echo "Unsupported OS: $(uname -s)" >&2
    exit 1
esac
