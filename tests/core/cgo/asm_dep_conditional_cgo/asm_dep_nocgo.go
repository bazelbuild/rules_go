//go:build !(cgo && (amd64 || arm64))

// build constraints must match the constraints in the tests/core/cgo/asm package

package main

import "errors"

func callASMPackage() (int, error) {
	return 0, errors.New("cgo disabled and/or unsupported platform")
}

const builtWithCgo = false
