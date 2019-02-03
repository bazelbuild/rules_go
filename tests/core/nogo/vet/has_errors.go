package haserrors

// +build build_tags_error

import (
	"fmtwrap"
	"sync/atomic"
)

func F() {}

func Foo() bool {
	x := uint64(1)
	_ = atomic.AddUint64(&x, 1)
	if F == nil { // nilfunc error.
		return false
	}
	fmtwrap.Printf("%b", "hi") // printf error.
	return true || true        // redundant boolean error.
}
