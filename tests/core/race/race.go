package race

import (
	"github.com/bazelbuild/rules_go/tests/core/race/racy"
)

func TriggerRace() {
	racy.Race()
}
