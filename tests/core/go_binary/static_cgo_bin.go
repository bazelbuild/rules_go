package main

/*
#include <stdio.h>

void say_hello() {
	printf("hello\n");
}
*/
import "C"

func main() {
	C.say_hello()
}
