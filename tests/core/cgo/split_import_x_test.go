package a_test

import (
	"testing"

	"github.com/bazelbuild/rules_go/tests/core/cgo/split_import/b"
)

func TestExternal(t *testing.T) {
	if b.HalfAnswer() != 21 {
		t.Error("wrong answer")
	}
}
