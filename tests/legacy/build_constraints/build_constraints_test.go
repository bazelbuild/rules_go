package build_constraints

import (
	"runtime"
	"testing"
)

func check(value string, t *testing.T) {
	var want string
	if runtime.GOOS == "linux" {
		want = "linux"
	} else {
		want = "unknown"
	}
	if value != want {
		t.Errorf("got %s; want %s", value, want)
	}
}

func TestSuffix(t *testing.T) {
	check(suffix, t)
}

func TestTag(t *testing.T) {
	check(tag, t)
}

func TestCgoGo(t *testing.T) {
	check(cgoGo, t)
}

func TestCgoC(t *testing.T) {
	check(cgoC, t)
}

func TestCgoCGroup(t *testing.T) {
	check(cgoCGroup, t)
}
