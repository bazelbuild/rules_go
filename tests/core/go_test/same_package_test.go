package same_package

import (
	"testing"
)

func OkTest(t *testing.T) {
	if name == "" {
		t.Errorf("expected name to be non empty")
	}
}
