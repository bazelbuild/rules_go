// +build !linux

package build_constraints

/*
const char* cgo = "unknown";
*/
import "C"

var cgo = C.GoString(C.cgo)
