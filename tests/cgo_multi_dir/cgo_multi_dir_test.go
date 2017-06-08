package cgo_multi_dir

import "testing"

func TestMultiDir(t *testing.T) {
	if got, want := foo+bar, 46; got != want {
		t.Errorf("got %d; want %d", got, want)
	}
}
