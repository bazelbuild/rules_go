# Macros used by all nogo integration tests.

BUILD_FAILED_TMPL = """
if [[ result -eq 0 ]]; then
  echo "TEST FAILED: expected build error" >&2
  result=1
else
  result=0
  {check_err}
fi
"""

BUILD_PASSED_TMPL = """
if [[ result -ne 0 ]]; then
  echo "TEST FAILED: unexpected build error" >&2
  result=1
else
  {check_err}
fi
"""

CONTAINS_ERR_TMPL = """
  lines=$(grep '{err}' bazel-output.txt | wc -l)
  if [ $lines -eq 0 ]; then
    echo "TEST FAILED: expected error message containing: '{err}'" >&2
    result=1
  elif [ $lines -ne 1 ]; then
    echo "TEST FAILED: expected error message '{err}' appears more than once" >&2
    result=1
  fi
"""

DOES_NOT_CONTAIN_ERR_TMPL = """
  if grep -q '{err}' bazel-output.txt; then
    echo "TEST FAILED: received error message containing: '{err}'" >&2
    result=1
  fi
"""
