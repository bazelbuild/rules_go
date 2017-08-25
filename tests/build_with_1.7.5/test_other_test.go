// +build go1.8

package test_version

import "testing"

func TestShouldFail(t *testing.T) {
	t.Fail()
}
