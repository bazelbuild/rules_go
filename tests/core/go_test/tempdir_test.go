package tempdir

import (
	"os"
	"testing"
)

func TestTempDir(t *testing.T) {
	testTmpDir := os.Getenv("TEST_TMPDIR")
	tmpDir := os.Getenv("TMPDIR")
	if testTmpDir != tmpDir {
		t.Errorf("Expect TMPDIR to be the same as TEST_TMPDIR, got %s and %s", tmpDir, testTmpDir)
	}
}