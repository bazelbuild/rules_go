// +build !linux

package build_constraints

/*
const char* cgoGo = "unknown";
const const char* cgoC;
const const char* cgoCGroup;
*/
import "C"

var cgoGo = C.GoString(C.cgoGo)
var cgoC = C.GoString(C.cgoC)
var cgoCGroup = C.GoString(C.cgoCGroup)
