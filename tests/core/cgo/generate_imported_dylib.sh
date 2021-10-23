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
    cc -shared -Wl,-install_name,@rpath/libversioned.dylib.2 -o libversioned.dylib.2 imported.c
    # Some libraries, such as Oracle Instant Client, are distributed as a versioned library
    # with a symlink
    ln -s libversioned.dylib.2 libversioned.dylib
    ;;
  *)
    echo "Unsupported OS: $(uname -s)" >&2
    exit 1
esac
