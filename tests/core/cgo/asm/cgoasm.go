//go:build amd64 || arm64

package asm

/*
extern int example_asm_func();
*/
import "C"

func CallAssembly() int {
	return int(C.example_asm_func())
}
