package dylib

/*
extern int foo();
*/
import "C"

func Foo() int {
	return int(C.foo())
}
