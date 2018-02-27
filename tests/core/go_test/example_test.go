package lib

import "fmt"

var Expected = "Expected"

func ExampleHelloWorld() {
	fmt.Println("Hello Example!")
	fmt.Println("expected: " + Expected)
	fmt.Println("got: " + Got)
	// Output:
	// Hello Example!
	// expected: Example
	// got: Example
}

func ExampleDontTestMe() {
	panic("Dont Test Me!")
}

func ExampleTestEmptyOutput() {
	if false {
		fmt.Println("Say something!")
	}
	// Output:
}

func ExampleTestQuoting() {
	fmt.Printf(`"quotes are handled"`)
	// Output:
	// "quotes are handled"
}
