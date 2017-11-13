package cgo_pure_test

import (
	"fmt"
	"testing"

	"github.com/bazelbuild/rules_go/tests/cgo_pure"
)

func TestValue(t *testing.T) {
	got := fmt.Sprintf("%d", cgo_pure.Value)
	if got != cgo_pure.Expect {
		t.Errorf("got %q; want %q", got, cgo_pure.Expect)
	}
}
