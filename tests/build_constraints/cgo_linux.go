package build_constraints

/*
const char* cgo = "linux";
*/
import "C"

var cgo = C.GoString(C.cgo)
