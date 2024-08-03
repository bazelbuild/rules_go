package stackpath

import (
	"fmt"
	"runtime/debug"
	"stackpath_default_lib"
	"stackpath_lib"
	"strings"
	"testing"
)

var expectedLibFile string
var expectedTestFile string

func TestStackPath(t *testing.T) {
	stack := stackpath_lib.Wrap(func() string {
		return string(debug.Stack())
	})
	for _, expectedFile := range []string{
		expectedLibFile,
		expectedTestFile,
	} {
		if expectedFile == "" {
			t.Fatalf("Unexpected empty value. Looks like x_defs missed.")
		}

		expectedSubstring := fmt.Sprintf("\n\t%s:", expectedFile)
		if !strings.Contains(stack, expectedSubstring) {
			t.Fatalf("Stacktrace does not contains substring %q: %s", expectedSubstring, stack)
		}
	}
}

func TestStackDefaultPath(t *testing.T) {
	stack := stackpath_default_lib.Wrap(func() string {
		return string(debug.Stack())
	})
	for _, expectedFile := range []string{
		"tests/core/go_test/stackpath_default_lib.go",
		expectedTestFile,
	} {
		if expectedFile == "" {
			t.Fatalf("Unexpected empty value. Looks like x_defs missed.")
		}

		expectedSubstring := fmt.Sprintf("\n\t%s:", expectedFile)
		if !strings.Contains(stack, expectedSubstring) {
			t.Fatalf("Stacktrace does not contains substring %q: %s", expectedSubstring, stack)
		}
	}
}
