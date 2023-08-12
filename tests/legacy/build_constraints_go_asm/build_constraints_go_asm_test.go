package build_constraints_go_asm

import (
	"runtime"
	"testing"
)

func asm() int

func TestAsm(t *testing.T) {
	got := asm()
	var want int
	if runtime.GOOS == "linux" {
		want = 12
	} else if runtime.GOARCH == "arm64" {
		want = 75
	} else {
		want = 34
	}
	if got != want {
		t.Errorf("got %d; want %d", got, want)
	}
}
