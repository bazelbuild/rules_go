package test_init

// This package must have no deps beyond Go SDK.
import (
	"os"
	"path/filepath"
	"strings"
)

// This initializer runs before any user packages.
func init() {
	// Change from the bazel test directory to the correct go test directory.
	if srcDir, ok := os.LookupEnv("TEST_SRCDIR"); ok {
		if workspace, ok := os.LookupEnv("TEST_WORKSPACE"); ok {
			if target, ok := os.LookupEnv("TEST_TARGET"); ok {
				if pos := strings.IndexRune(target, ':'); pos > 0 {
					cwd := filepath.Join(srcDir, workspace, target[:pos])
					_ = os.Chdir(cwd)
					_ = os.Setenv("PWD", cwd)
				}
			}
		}
	}

	// Setup the bazel tmpdir as the go tmpdir.
	if tmpDir, ok := os.LookupEnv("TEST_TMPDIR"); ok {
		_ = os.Setenv("TMPDIR", tmpDir)
	}
}
