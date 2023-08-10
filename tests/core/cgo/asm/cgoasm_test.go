package asm

import (
	"testing"
	"runtime"
)

func TestNativeAssembly(t *testing.T) {
	expectedGOARCH := map[string]int{
		"amd64": 42,
		"arm64": 44,
	}
	expected := expectedGOARCH[runtime.GOARCH]
	if expected == 0 {
		t.Fatalf("expected=0 for GOARCH=%s; missing value?", runtime.GOARCH)
	}
	actual := callAssembly()
	if actual != expected {
		t.Errorf("callAssembly()=%d; expected=%d", actual, expected)
	}
}
