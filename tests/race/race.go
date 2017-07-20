package race

import (
	"github.com/bazelbuild/rules_go/tests/race/racy"
)

func TriggerRace() {
	racy.Race()
}
