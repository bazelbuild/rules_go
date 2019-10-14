// +build go1.12

package test_version

import "testing"

func TestShouldFail(t *testing.T) {
	t.Fail()
}
