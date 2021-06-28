package main

/*
#define CGO_EXPORT_H_EXISTS
#include "tests/core/c_linkmodes/add_sandwich.h"
*/
import "C"

//export GoAdd
func GoAdd(a, b int) int {
	return int(C.add(C.int(a), C.int(b)))
}

func main() {}
