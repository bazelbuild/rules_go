package haserrors

import (
	_ "fmt" // This should fail importfmt
)

func Foo() bool { // This should fail foofuncname
	return true // This should fail boolreturn
}
