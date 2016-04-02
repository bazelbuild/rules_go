package main

import (
	"testing"
)

func TestExtract(t *testing.T) {
	for _, fname := range []string{
		"extract.go",
		"extract_test.go",
		"ignored.go",
	} {
		name, err := extract(fname)
		if err != nil {
			t.Errorf("extract(%q) fails with %v; want success", fname, err)
		}
		if got, want := name, "main"; got != want {
			t.Errorf("extract(%q) = %q; want %q", fname, got, want)
		}
	}
}
