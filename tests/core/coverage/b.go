package b

import "github.com/bazelbuild/rules_go/tests/core/coverage/c"

func BLive() int {
	return c.CLive()
}

func BDead() int {
	return c.CDead()
}
