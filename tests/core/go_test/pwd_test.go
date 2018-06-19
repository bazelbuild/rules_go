package pwd

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestPwd(t *testing.T) {
	pwd := os.Getenv("PWD")
	suffix := filepath.FromSlash("tests/core/go_test")
	if !strings.HasSuffix(pwd, filepath.FromSlash(suffix)) {
		t.Errorf("PWD not set. got %q; want something ending with %q", pwd, suffix)
	}
}
