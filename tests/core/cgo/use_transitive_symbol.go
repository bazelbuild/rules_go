package main

import "C"

import (
	"github.com/bazelbuild/rules_go/tests/core/cgo/direct_dep"
)

//export PrintGreeting
func PrintGreeting() {
	direct_dep.PrintGreeting()
}

func main() {}
