package slash

import (
	"testing"

	a "github.com/bazelbuild/rules_go/tests/slash_names/a/pkg"
	b "github.com/bazelbuild/rules_go/tests/slash_names/b/pkg"
)

func TestSlash(t *testing.T) {
	if name := a.Name(); name != "A" {
		t.Errorf("got %s; want A", name)
	}
	if name := b.Name(); name != "B" {
		t.Errorf("got %s; want B", name)
	}
}
