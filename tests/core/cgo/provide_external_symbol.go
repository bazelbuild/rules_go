package main

import "C"

import "github.com/bazelbuild/rules_go/tests/core/cgo/use_external_symbol"

//export external_symbol
func external_symbol() {}

func main() {
	use_external_symbol.UseExternalSymbol()
}
