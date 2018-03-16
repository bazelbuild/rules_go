package main

import (
	"os"
	"testing"
)

func TestCustomBinaryName(t *testing.T) {
	_, err := os.Stat("alt_bin")
	if err != nil {
		t.Error(err)
	}
}
