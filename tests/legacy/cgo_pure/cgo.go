//+build cgo

package cgo_pure

/*
extern const int value;
*/
import "C"

var Value = int(C.value)
