// +build go1.9

package test_version

import "testing"

func TestShouldFail(t *testing.T) {
	t.Fail()
}
