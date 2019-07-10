package main

// #define CGO_EXPORT_H_EXISTS
import "C"

//export GoAdd
func GoAdd(a, b int) int {
	return a + b
}

func main() {}
