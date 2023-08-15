package main

import (
	"fmt"
)

func main() {
	result, err := callASMPackage()
	if err != nil {
		fmt.Printf("callASMPackage() returned err=%s\n", err.Error())
	} else {
		fmt.Printf("callASMPackage() == %d\n", result)
	}
}
