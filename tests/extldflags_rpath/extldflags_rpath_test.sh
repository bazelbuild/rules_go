#!/bin/sh

if [ $# -ne 1 ]; then
  echo "usage: $0 binaryfile" >&1
  exit 1
fi

binaryfile=$1
os=$(uname)
case $os in
  Linux)
    output=$(readelf --dynamic "$binaryfile")
    ;;
  Darwin)
    output=$(otool -l "$binaryfile")
    ;;
  *)
    echo "unsupported platform: $os" >&1
    exit 1
esac

for path in /foo /bar ; do
  if ! echo "$output" | grep --quiet "$path" ; then
    echo "$binaryfile: could not find $path in rpaths" >&1
    exit 1
  fi
done
