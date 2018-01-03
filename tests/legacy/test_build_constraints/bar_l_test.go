// +build linux

package test_build_constraints

import (
	"runtime"
	"testing"
)

func TestBarLinux(t *testing.T) {
	if runtime.GOOS != "linux" {
		t.Errorf("got %s; want linux", runtime.GOOS)
	}
}
