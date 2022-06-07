package direct_dep

import (
	"github.com/bazelbuild/rules_go/tests/core/cgo/transitive_dep"
)

func PrintGreeting() {
	transitive_dep.PrintGreeting()
}
