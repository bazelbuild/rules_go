package stackpath

import (
	"fmt"
	"runtime/debug"
	"stackpath_lib"
	"strings"
	"testing"
)

var expectedSubdirTestFile string

func TestStackPathSubdir(t *testing.T) {
	stack := stackpath_lib.Wrap(func() string {
		return string(debug.Stack())
	})
	for _, expectedFile := range []string{
		expectedLibFile,
		expectedSubdirTestFile,
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
