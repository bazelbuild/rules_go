package output_groups

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCompilationOutputs(t *testing.T) {
	expectedFiles := map[string]bool{
		"compilation_outputs_test": true, // test binary; not relevant

		"lib%/lib.a":                          true, // :lib archive
		"lib_test%/lib.a":                     true, // :lib_test archive
		"bin%/tests/core/output_groups/bin.a": true, // :bin archive
	}

	filepath.Walk(".", func(path string, info os.FileInfo, err error) error {
		if info.IsDir() {
			return nil
		}
		// Remove first directory of file (e.g. linux_amd64_stripped)
		if firstSlash := strings.Index(path, "/"); firstSlash >= 0 {
			path = path[firstSlash+1:]
		}
		if expectedFiles[path] {
			delete(expectedFiles, path)
		} else {
			t.Errorf("Runfiles contains an unexpected file: %s", path)
		}
		return nil
	})

	if len(expectedFiles) != 0 {
		var missingFiles []string
		for path := range expectedFiles {
			missingFiles = append(missingFiles, path)
		}
		t.Errorf("Could find expected files: %v", missingFiles)
	}
}
