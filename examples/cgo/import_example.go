package cgo

import (
	//#cgo LDFLAGS: -lm -lversion -lc_version -L${SRCDIR}/cc_dependency
	//#cgo CPPFLAGS: -I${SRCDIR}/../..
	//#include <math.h>
	//#include "use_exported.h"
	//#include "cc_dependency/version.h"
	"C"
	"math"
)

// Nsqrt returns the square root of n.
func Nsqrt(n int) int {
	return int(math.Floor(float64(C.sqrt(C.double(n)))))
}

func PrintGoVersion() {
	C.PrintGoVersion()
}

func printCXXVersion() {
	C.PrintCXXVersion()
}
