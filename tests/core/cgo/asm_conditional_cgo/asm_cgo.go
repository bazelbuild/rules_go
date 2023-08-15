//go:build amd64 || arm64

// build constraints must match the constraints in the tests/core/cgo/asm package

package main

/*
extern int example_asm_func();
*/
import "C"

func callASM() (int, error) {
	return int(C.example_asm_func()), nil
}

const builtWithCgo = true
