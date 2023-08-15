//go:build !(cgo && (amd64 || arm64))

package main

import "errors"

func callASM() (int, error) {
	return 0, errors.New("cgo disabled and/or unsupported platform")
}

const builtWithCgo = false
