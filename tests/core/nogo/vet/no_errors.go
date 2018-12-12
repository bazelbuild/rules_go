package noerrors

// const int x = 1;
import "C"

func Foo() bool {
	return bool(C.x == 1)
}
