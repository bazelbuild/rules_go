// +build go1.11

package test_version

import "testing"

func TestShouldFail(t *testing.T) {
	t.Fail()
}
