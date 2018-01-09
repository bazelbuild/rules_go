//+build cgo

package cgo_pure

/*
const int value;
*/
import "C"

var Value = int(C.value)
