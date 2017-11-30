package cgo

/*
const int value;
*/
import "C"

var Value = int(C.value)
