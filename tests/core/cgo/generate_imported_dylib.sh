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
    # According to "Mac OS X For Unix Geeks", 4th Edition, Chapter 11, versioned dylib for macOS
    # should be libversioned.2.dylib.
    cc -shared -Wl,-install_name,@rpath/libversioned.2.dylib -o libversioned.2.dylib imported.c
    # However, Oracle Instant Client was distributed as libclntsh.dylib.12.1 with a unversioed
    # symlink (https://www.oracle.com/database/technologies/instant-client/macos-intel-x86-downloads.html).
    # Let's cover this non-standard case as well.
    cc -shared -Wl,-install_name,@rpath/libversioned.dylib.2 -o libversioned.dylib.2 imported.c
    ln -fs libversioned.dylib.2 libversioned.dylib
    ;;
  *)
    echo "Unsupported OS: $(uname -s)" >&2
    exit 1
esac
