package cgo_multi_dir

// int foo = 12;
import "C"

var foo = int(C.foo)
