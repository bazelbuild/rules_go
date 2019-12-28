package gendefs

import "testing"

func TestMultipleDirs(t *testing.T) {
	if MyFoo != 2 {
		t.Errorf("MyFoo was incorrect, got: %d, want: %d.", MyFoo, 2)
	}

	if MyBar != 3 {
		t.Errorf("MyBar was incorrect, got: %d, want: %d.", MyBar, 3)
	}
}
