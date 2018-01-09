package foo

import "testing"

func TestFoo(t *testing.T) {
	x := foo()
	if x != 42 {
		t.Errorf("got %d; want %d", x, 42)
	}
}
