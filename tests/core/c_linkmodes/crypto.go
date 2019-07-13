package main

import "C"

import (
	"crypto/rand"

	"golang.org/x/crypto/nacl/box"
)

//export GoFn
func GoFn() {
	box.GenerateKey(rand.Reader)
	return
}

func main() {
}
