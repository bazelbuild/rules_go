package race

import (
	"os"
	"os/exec"
	"testing"

	"github.com/bazelbuild/rules_go/tests/core/race/racy"
)

func TestRaceTest(t *testing.T) {
	checkRaceBinary(t, os.Args[1])
}

func TestRaceBin(t *testing.T) {
	checkRaceBinary(t, os.Args[2])
}

func TestRaceTag(t *testing.T) {
	if !racy.RaceEnabled {
		t.Error("RaceEnabled: got false, want true")
	}
}

func checkRaceBinary(t *testing.T, bin string) {
	err := exec.Command(bin).Run()
	if _, ok := err.(*exec.ExitError); !ok {
		t.Errorf("want ExitError; got %v", err)
	}
}
