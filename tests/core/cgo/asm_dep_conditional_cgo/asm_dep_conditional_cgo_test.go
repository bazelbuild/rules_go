package main

import "testing"

func TestConditionalCgo(t *testing.T) {
	// Uses build constraints to depend on a native Cgo package when cgo is available, or a
	// pure go version if it is not. This can be run both with and without cgo. E.g.:
	// CGO_ENABLED=0 go test . && CGO_ENABLED=1 go test .
	result, err := callASMPackage()
	if builtWithCgo {
		if err != nil {
			t.Errorf("builtWithCgo=%t; err must be nil, was %s", builtWithCgo, err.Error())
		} else if result <= 0 {
			t.Errorf("builtWithCgo=%t; result must be > 0 was %d", builtWithCgo, result)
		}
	} else {
		// does not support calling the cgo library
		if !(result == 0 && err != nil) {
			t.Errorf("builtWithCgo=%t; expected result=0, err != nil; result=%d, err=%#v", builtWithCgo, result, err)
		}
	}
}
