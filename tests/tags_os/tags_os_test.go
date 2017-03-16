package tags_os

import (
	"runtime"
	"testing"
)

func check(name, value string, t *testing.T) {
	var expected string
	if runtime.GOOS == "linux" || runtime.GOOS == "darwin" {
		expected = name + "_" + runtime.GOOS
	} else {
		expected = name + "_unknown"
	}
	if value != expected {
		t.Errorf("got %s; want %s", value, expected)
	}
}

func TestFoo(t *testing.T) {
	check("foo", foo, t)
}

func TestBar(t *testing.T) {
	check("bar", bar, t)
}
