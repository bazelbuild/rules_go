package main

import (
	"fmt"

	"example.com/stamp_dep"
)

var Bin = "redacted"

func main() {
	fmt.Printf("Bin=%s\n", Bin)
	fmt.Printf("Embed=%s\n", Embed)
	fmt.Printf("DepSelf=%s\n", stamp_dep.DepSelf)
	fmt.Printf("DepBin=%s\n", stamp_dep.DepBin)
}
