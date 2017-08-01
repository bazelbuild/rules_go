package cgo_filtered

import "testing"

func TestFoo(t *testing.T) {
	if got, want := Value, 42; got != want {
		t.Errorf("got %d; want %d", got, want)
	}
}
