package main

import (
	"fmt"
)

func main() {
	result, err := callASM()
	if err != nil {
		fmt.Printf("callASM() returned err=%s\n", err.Error())
	} else {
		fmt.Printf("callASM() == %d\n", result)
	}
}
