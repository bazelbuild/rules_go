package sub

import (
	//#cgo LDFLAGS: -lm
	//#include <math.h>
	"C"
)

// Floor calculates floor of the given number
// with the implementation in the standard C library.
func Floor(f float64) float64 {
	return float64(C.floor(C.double(f)))
}
