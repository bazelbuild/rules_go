package fmtwrap

import "fmt"

func Printf(format string, args ...interface{}) {
	fmt.Printf(format, args...)
}
