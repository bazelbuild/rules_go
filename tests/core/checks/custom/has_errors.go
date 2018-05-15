// package haserrors contains analysis errors.
package haserrors

func Foo() {} // This should fail foo_func_check

func Bar() bool { // This should fail return_bool_check
	return true
}
