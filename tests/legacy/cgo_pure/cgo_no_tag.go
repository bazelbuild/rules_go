package cgo_pure

/*
const int value;
*/
import "C"

var AnotherValue = int(C.value)
