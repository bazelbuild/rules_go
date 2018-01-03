package cgo_sys_hdr

/*
#include <sub/foo.h>
*/
import "C"

var x = int(C.x)
