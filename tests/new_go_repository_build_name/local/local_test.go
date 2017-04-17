package local

import (
	"testing"

	"remote/build"
)

func TestBuildValue(t *testing.T) {
	if got, want := build.Foo, 42; got != want {
		t.Errorf("got %d; want %d", got, want)
	}
}
