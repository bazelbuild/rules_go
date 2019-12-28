package gendefs

import "testing"

func TestMultipleDirs(t *testing.T) {
	if MyFooA != 3 {
		t.Errorf("MyFooA was incorrect, got: %d, want: %d.", MyFooA, 3)
	}

	if MyFooB != 3 {
		t.Errorf("MyFooB was incorrect, got: %d, want: %d.", MyFooB, 3)
	}
}
