package cgo_opts

/*
#cgo CFLAGS: -DFOO=1 -DBAR=2 -g -O2
int x = FOO + BAR;
*/
import "C"

var x = int(C.x)
