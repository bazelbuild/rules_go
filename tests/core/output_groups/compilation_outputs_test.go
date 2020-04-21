package output_groups

import (
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel"
)

func TestCompilationOutputs(t *testing.T) {
	runfiles, err := bazel.ListRunfiles()
	if err != nil {
		t.Fatal(err)
	}

	exe := ""
	if runtime.GOOS == "windows" {
		exe = ".exe"
	}
	expectedFiles := map[string]bool{
		"compilation_outputs_test" + exe: true, // test binary; not relevant

		"lib.a":               true, // :lib archive
		"lib_test.internal.a": true, // :lib_test archive
		"bin.a":               true, // :bin archive
	}
	for _, rf := range runfiles {
		info, err := os.Stat(rf.Path)
		if err != nil {
			t.Error(err)
			continue
		}
		if info.IsDir() {
			continue
		}

		base := strings.TrimSuffix(filepath.Base(rf.Path), ".exe")
		if expectedFiles[base] {
			delete(expectedFiles, base)
		} else {
			t.Errorf("unexpected runfile: %s", rf.Path)
		}
	}

	if len(expectedFiles) != 0 {
		var missingFiles []string
		for path := range expectedFiles {
			missingFiles = append(missingFiles, path)
		}
		sort.Strings(missingFiles)
		t.Errorf("Could find expected files: %s", strings.Join(missingFiles, " "))
	}
}
