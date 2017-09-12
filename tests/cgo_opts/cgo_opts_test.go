package cgo_opts

import "testing"

func TestCOpts(t *testing.T) {
	if x != 3 {
		t.Errorf("got %d; want 3", x)
	}
}
