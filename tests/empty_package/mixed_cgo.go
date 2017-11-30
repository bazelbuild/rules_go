//+build cgo

package mixed

import (
	"github.com/bazelbuild/rules_go/tests/empty_package/cgo"
)

var Value = cgo.Value
var Expect = ""
