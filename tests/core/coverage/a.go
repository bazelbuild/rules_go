package a

import "github.com/bazelbuild/rules_go/tests/core/coverage/b"

func ALive() int {
	return b.BLive()
}

func ADead() int {
	return b.BDead()
}
