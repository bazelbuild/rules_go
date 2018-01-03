package cgo_sys_hdr

import "testing"

func TestFoo(t *testing.T) {
	if x != 42 {
		t.Errorf("got %d; want %d", x, 42)
	}
}
