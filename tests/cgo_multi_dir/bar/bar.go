package cgo_multi_dir

// int bar = 34;
import "C"

var bar = int(C.bar)
