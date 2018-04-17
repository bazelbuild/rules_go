package dylib

import "testing"

func TestFoo(t *testing.T) {
	want := 42
	if got := Foo(); got != want {
		t.Errorf("got %d ; want %d", got, want)
	}
}
