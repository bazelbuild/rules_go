package lib

import (
	"testing"
)

func TestName(t *testing.T) {
	if Name() != "bzlmod" {
		t.Fail()
	}
}
