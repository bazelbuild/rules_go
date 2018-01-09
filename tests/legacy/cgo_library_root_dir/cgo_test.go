package cgo_library_root_dir

import "testing"

func TestFoo(t *testing.T) {
	if got, want := Foo, 42; got != want {
		t.Errorf("got %d; want %d", got, want)
	}
}
