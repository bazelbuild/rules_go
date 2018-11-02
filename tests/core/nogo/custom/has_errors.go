package haserrors

import (
	_ "fmt" // This should fail importfmt

	"dep"
)

func Foo() bool { // This should fail foofuncname
	dep.D()     // This should fail visibility
	return true // This should fail boolreturn
}
