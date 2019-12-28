package gendefs

// #include "foo.h"
import "C"

const What int32 = C.MY_FOO
