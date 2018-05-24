package version

import (
	"runtime"
	"testing"
)

const expected = "go1.10.1"

func TestVersion(t *testing.T) {
	if expected != runtime.Version() {
		t.Fatalf("Incorrect go version, expected %s got %s", expected, runtime.Version())
	}
}
