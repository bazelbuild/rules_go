package test_build_constraints

import (
	"runtime"
	"testing"
)

func TestFooLinux(t *testing.T) {
	if runtime.GOOS != "linux" {
		t.Errorf("got %s; want linux", runtime.GOOS)
	}
}
