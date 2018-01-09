package empty_package_test

import (
	"fmt"
	"testing"

	"github.com/bazelbuild/rules_go/tests/empty_package/mixed"
)

var Expect = ""

func TestValue(t *testing.T) {
	got := fmt.Sprintf("%d", mixed.Value)
	if got != Expect {
		t.Errorf("got %q; want %q", got, Expect)
	}
}
