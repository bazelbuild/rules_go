package cgo_select

/*
extern const char* goos;
*/
import "C"

var goos = C.GoString(C.goos)
