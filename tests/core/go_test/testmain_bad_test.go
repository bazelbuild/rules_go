// +build !good

package testmain_bad

import "testing"

func TestMain(m *testing.M) {
	m.Run()
}

func Test(t *testing.T) {
	t.Fail()
}
