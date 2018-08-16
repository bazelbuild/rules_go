package haserrors

import (
	_ "fmt" // This should fail import_fmt_check
)

func Foo() bool { // This should fail foo_func_check
	return true // This should fail return_bool_check
}
