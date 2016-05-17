package lib

import "fmt"

func add(x, y int64) int64
func sub(x, y int64) int64

func AddTwoNumbers() {
	fmt.Println("2 + 3 =", add(2, 3))
}

func SubTwoNumbers() {
	fmt.Println("2 - 3 =", sub(2, 3))
}