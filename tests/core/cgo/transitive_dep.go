package transitive_dep

/*
#include "tests/core/cgo/native_dep.h"
 */
import "C"

func PrintGreeting() {
	C.native_greeting();
}
