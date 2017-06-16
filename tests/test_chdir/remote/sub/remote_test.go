package sub

import (
	"os"
	"testing"
)

func TestRemote(t *testing.T) {
	_, err := os.Stat("remote.txt")
	if err != nil {
		t.Errorf("could not stat remote.txt: %v", err)
	}
}
