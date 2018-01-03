package build_test

import (
	"testing"

	"github.com/bazelbuild/rules_go/tests/package_named_build/build"
)

func TestBuildValue(t *testing.T) {
	if got, want := build.Foo, 42; got != want {
		t.Errorf("got %d; want %d", got, want)
	}
}
