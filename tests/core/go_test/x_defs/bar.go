package bar

import (
	"github.com/bazelbuild/rules_go/tests/core/go_test/x_defs/baz"
	_ "github.com/bazelbuild/rules_go/tests/core/go_test/x_defs/foo"
)

var Bar string
var Qux = baz.Qux
var Baz = baz.Baz
