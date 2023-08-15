//go:build cgo && (amd64 || arm64)

// build constraints must match the constraints in the tests/core/cgo/asm package

package main

import (
	"github.com/bazelbuild/rules_go/tests/core/cgo/asm"
)

func callASMPackage() (int, error) {
	return asm.CallAssembly(), nil
}

const builtWithCgo = true
