package objc

import (
	"fmt"
	"math/rand"
	"testing"
)

func TestObjcMethod(t *testing.T) {
	a := rand.Int31()
	b := rand.Int31()
	expected := a + b
	if result := Add(a, b); result != expected {
		t.Error(fmt.Errorf("wrong result: expected %d, got %d", expected, result))
	}
}
