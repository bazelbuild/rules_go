package cgo_pure

/*
extern const int value;
*/
import "C"

var AnotherValue = int(C.value)
