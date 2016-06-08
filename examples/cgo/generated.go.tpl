package cgo

import (
	//#cgo LDFLAGS: -lm
	//#include <math.h>
	"C"
	"math"
)

// Ncbrt returns the cube root of n.
func Ncbrt(n int) int {
	return int(math.Floor(float64(C.cbrt(C.double(n)))))
}
