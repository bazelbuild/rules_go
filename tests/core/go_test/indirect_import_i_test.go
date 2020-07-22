package indirect_import

import "testing"

func TestMain(m *testing.M) {
	X = "set by TestMain"
}
