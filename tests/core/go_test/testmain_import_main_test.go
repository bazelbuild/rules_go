package test_main

import "testing"

var Updated bool

func TestShouldPass(t *testing.T) {
	if !Updated {
		t.Fail()
	}
}
