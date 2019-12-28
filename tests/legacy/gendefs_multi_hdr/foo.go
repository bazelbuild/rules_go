package gendefs

// #include "foo.h"
// #include "bar.h"
import "C"

const MyFoo int32 = C.MY_FOO

type Bar C.struct_Bar

const Sizeof_Bar = C.sizeof_struct_Bar
