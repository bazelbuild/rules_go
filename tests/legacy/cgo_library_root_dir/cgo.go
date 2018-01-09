package cgo_library_root_dir

/*
const int foo;
*/
import "C"

var Foo = int(C.foo)
