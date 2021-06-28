#!/usr/bin/env bash

set -exo pipefail

cd "$(dirname "$0")"

case "$(uname -s)" in
  Linux*)
    cc -shared -o libimported.so imported.c
    cc -shared -o libimported.so.2 imported.c
    ;;
  Darwin*)
    cc -shared -Wl,-install_name,@rpath/libimported.dylib -o libimported.dylib imported.c
    ;;
  *)
    echo "Unsupported OS: $(uname -s)" >&2
    exit 1
esac
