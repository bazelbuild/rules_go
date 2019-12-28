package gendefs

import "testing"

func TestMultipleHeaders(t *testing.T) {
	if MyFoo != 2 {
		t.Errorf("MyFoo was incorrect, got: %d, want: %d.", MyFoo, 2)
	}

	bar := Bar{Bar1: 1, Bar2: 2}
	if bar.Bar1 != 1 {
		t.Errorf("bar.Bar1 was incorrect, got: %d, want: %d.", bar.Bar1, 1)
	}

	if bar.Bar2 != 2 {
		t.Errorf("bar.Bar2 was incorrect, got: %d, want: %d.", bar.Bar2, 2)
	}

	if Sizeof_Bar != 8 {
		t.Errorf("Sizeof_Bar was incorrect, got: %d, want: %d.", Sizeof_Bar, 8)
	}
}
