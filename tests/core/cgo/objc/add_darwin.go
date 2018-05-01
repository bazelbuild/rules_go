package objc

/*
#include "add_darwin.h"
*/
import "C"

func Add(a, b int32) int32 {
	return int32(C.add(C.int(a), C.int(b)))
}
