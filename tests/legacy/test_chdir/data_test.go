package test_chdir

import (
	"os"
	"testing"
)

func TestLocal(t *testing.T) {
	_, err := os.Stat("data.txt")
	if err != nil {
		t.Errorf("could not stat local.txt: %v", err)
	}
}
