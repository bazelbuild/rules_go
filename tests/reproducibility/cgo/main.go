package main

import "fmt"

func main() {
	// Depend on some stdlib function.
	fmt.Println("In C, 2 + 2 = ", AddC(2, 2))
	fmt.Println("In C++, 2 + 2 = ", AddCPP(2, 2))
}
