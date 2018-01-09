package test_rundir

import (
	"os"
	"testing"
)

func TestRunDir(t *testing.T) {
	if _, err := os.Stat("AUTHORS"); err != nil {
		t.Error(err)
	}
}
