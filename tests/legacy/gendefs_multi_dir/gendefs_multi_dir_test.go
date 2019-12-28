package gendefs

import "testing"

func TestMultipleDirs(t *testing.T) {
	if MyBar != 3 {
		t.Errorf("MyBar was incorrect, got: %d, want: %d.", MyBar, 3)
	}

	if What != 2 {
		t.Errorf("MyFoo was incorrect, got: %d, want: %d.", What, 2)
	}
}
