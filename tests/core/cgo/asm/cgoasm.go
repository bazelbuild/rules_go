package asm

/*
extern int example_asm_func();
*/
import "C"

func callAssembly() int {
	return int(C.example_asm_func())
}
