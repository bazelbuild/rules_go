#!/bin/bash

# This test verifies that flags passed through gc_goopts and gc_link_opts
# attributes in go_library, go_binary, go_test, and cgo_library are actually
# passed to the Go compiler.
#
# Each of the targets listed below is expected to fail, but only if the
# "-u" flag is passed to the compiler or linker (reject unsafe code). This
# test builds the targets manually and verifies Bazel fails with the expected
# error message.

cd $(dirname "$0")

result=0

function check_build_fails {
  local target=$1
  local message=$2
  local outfile=$(mktemp)
  bazel build "$target" 2>&1 | tee "$outfile"
  local target_result=${PIPESTATUS[0]}
  if [ $target_result -eq 0 ]; then
    echo "build of $target succeeded but should have failed" >&2
    echo "wrote output to $outfile" >&2
    return 1
  fi
  if ! grep -q "$message" "$outfile"; then
    echo "build of $target failed for a different reason" >&2
    return 1
  fi
  return 0
}

compile_test_targets=(
  :unsafe_srcs_lib
  :unsafe_library_lib
  :unsafe_srcs_bin
  :unsafe_library_bin
  :unsafe_srcs_test
  :unsafe_library_test
  :unsafe_cgo_lib
  :unsafe_cgo_client_lib
)

for target in "${compile_test_targets[@]}"; do 
  check_build_fails "$target" "cannot import package unsafe"
  if [ $? -ne 0 ]; then
    result=1
  fi
done

link_test_targets=(
  :unsafe_link_bin
  :unsafe_link_test  
)

for target in "${link_test_targets[@]}"; do
  check_build_fails "$target" "load of unsafe package"
  if [ $? -ne 0 ]; then
    result=1
  fi
done

exit $result
