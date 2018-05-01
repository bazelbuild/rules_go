package a

// const int ax = 42;
import "C"

import "github.com/bazelbuild/rules_go/tests/core/coverage/b"

func ACgoLive() int {
	return b.BCgoLive() + int(C.ax)
}

func ACgoDead() int {
	return b.BCgoDead() + int(C.ax)
}
