package stackpath

import (
	"runtime/debug"
	"stackpath_lib"
	"strings"
	"testing"
)

func TestStackPath(t *testing.T) {
	stack := stackpath_lib.Wrap(func() string {
		return string(debug.Stack())
	})
	// Stack example:
	//
	//	goroutine 7 [running]:
	//	runtime/debug.Stack()
	//		GOROOT/src/runtime/debug/stack.go:24 +0x65
	//	tests/core/go_test/stackpath_test.TestStackPath.func1(...)
	//		bar/stackpath_test.go:12
	//	stackpath_lib.Wrap(...)
	//		foo/stackpath_lib.go:4
	//	tests/core/go_test/stackpath_test.TestStackPath(0xc00009a9c0)
	//		bar/stackpath_test.go:11 +0x35
	//	testing.tRunner(0xc00009a9c0, 0x575e50)
	//		GOROOT/src/testing/testing.go:1439 +0x102
	//	created by testing.(*T).Run
	//		GOROOT/src/testing/testing.go:1486 +0x35f
	for _, expected := range []string{
		"\tbar/stackpath_test.go:",
		"\tfoo/stackpath_lib.go:",
	} {
		if !strings.Contains(stack, expected) {
			t.Fatalf("Stacktrace does not contains substring %q", expected)
		}
	}
}
