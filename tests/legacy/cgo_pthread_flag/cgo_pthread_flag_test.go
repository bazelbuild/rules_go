package cgo_pthread_flag

import "testing"

// Checks that we can build and run pthread code without explicitly giving
// any flags to cgo. -pthread should be passed to the C compiler by default.
func TestCgoPthread(t *testing.T) {
	x := int(callFFromGo())
	if x != 42 {
		t.Errorf("got %d; want 42", x)
	}
}
