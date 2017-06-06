package cgo_select

import (
	"runtime"
	"testing"
)

func TestGoos(t *testing.T) {
	if got, want := goos, runtime.GOOS; got != want {
		t.Errorf("got %s; want %s\n", got, want)
	}
}
