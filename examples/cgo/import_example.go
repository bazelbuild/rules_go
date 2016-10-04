package cgo

import (
	//#cgo LDFLAGS: -lm -lversion -lc_version -L${SRCDIR}/cc_dependency
	//#cgo CPPFLAGS: -I${SRCDIR}/../..
	//#include <math.h>
	//#include "use_exported.h"
	//#include "cc_dependency/version.h"
	"C"

	"github.com/bazelbuild/rules_go/examples/cgo/sub"
)

// Nsqrt returns the square root of n.
func Nsqrt(n int) int {
	return int(sub.Floor(float64(C.sqrt(C.double(n)))))
}

func PrintGoVersion() {
	C.PrintGoVersion()
}

func printCXXVersion() {
	C.PrintCXXVersion()
}

func ReturnDefined() int {
	return int(C.DEFINED_IN_COPTS)
}
