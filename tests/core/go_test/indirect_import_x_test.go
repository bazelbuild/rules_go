package indirect_import_test

import (
	"testing"

	"github.com/bazelbuild/rules_go/tests/core/go_test/indirect_import_dep"
)

func Test(t *testing.T) {
	got := indirect_import_dep.GetX()
	want := "set by TestMain"
	if got != want {
		t.Errorf("got %q; want %q", got, want)
	}
}
