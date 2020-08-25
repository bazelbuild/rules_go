package cgo

/*
#include "tests/core/cgo/split_import_c.h"
*/
import "C"

func Half(x int) int {
	return int(C.half(C.int(x)))
}
