package main

import (
	"fmt"

	"github.com/bazelbuild/rules_go/examples/cgo"
)

func main() {
	fmt.Println("floor(sqrt(10)) = ", cgo.Nsqrt(10))
	cgo.PrintGoVersion()
	cgo.PrintCXXVersion()
}
