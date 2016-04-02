package cgo

import (
	"math"
	"testing"
)

func TestNsqrt(t *testing.T) {
	for _, n := range []int{1, 2, 10, 100, 1000} {
		got, want := Nsqrt(n), int(math.Floor(math.Sqrt(float64(n))))
		if got != want {
			t.Errorf("Nsqrt(n) = %d; want %d", got, want)
		}
	}
}
