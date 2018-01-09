package cgo_trans_deps

import (
	"testing"

	"github.com/bazelbuild/rules_go/tests/cgo_trans_deps/dep"
)

func TestCgoTransDeps(t *testing.T) {
	if dep.X != 42 {
		t.Errorf("got %d; want %d", dep.X, 42)
	}
}
