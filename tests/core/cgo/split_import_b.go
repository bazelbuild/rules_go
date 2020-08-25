package b

import (
	"github.com/bazelbuild/rules_go/tests/core/cgo/split_import/a"
	"github.com/bazelbuild/rules_go/tests/core/cgo/split_import/cgo"
)

func HalfAnswer() int {
	return cgo.Half(a.Answer())
}
