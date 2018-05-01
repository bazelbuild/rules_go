package b

// const int bx = 99;
import "C"

import "github.com/bazelbuild/rules_go/tests/core/coverage/c"

func BCgoLive() int {
	return c.CCgoLive() + int(C.bx)
}

func BCgoDead() int {
	return c.CCgoDead() + int(C.bx)
}
