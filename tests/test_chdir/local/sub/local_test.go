package sub

import (
	"os"
	"testing"
)

func TestLocal(t *testing.T) {
	_, err := os.Stat("local.txt")
	if err != nil {
		t.Errorf("could not stat local.txt: %v", err)
	}
}
