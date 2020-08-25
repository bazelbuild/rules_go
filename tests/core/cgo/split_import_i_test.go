package a

import "testing"

func TestInternal(t *testing.T) {
	if Answer() != 42 {
		t.Error("wrong answer")
	}
}
