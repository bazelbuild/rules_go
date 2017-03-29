// +build !linux

package test_build_constraints

import (
	"runtime"
	"testing"
)

func TestFooUnknown(t *testing.T) {
	if runtime.GOOS == "linux" {
		t.Errorf("got %s; want not linux", runtime.GOOS)
	}
}
