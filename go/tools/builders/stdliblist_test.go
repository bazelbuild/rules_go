package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func Test_stdliblist(t *testing.T) {
	testDir := t.TempDir()
	outJSON := filepath.Join(testDir, "out.json")

	test_args := []string{
		fmt.Sprintf("-out=%s", outJSON),
		"-sdk=external/go_sdk",
	}

	if err := stdliblist(test_args); err != nil {
		t.Errorf("calling stdliblist got err: %v", err)
	}
	f, err := os.Open(outJSON)
	if err != nil {
		t.Errorf("cannot open output json: %v", err)
	}
	defer func() { _ = f.Close() }()
	decoder := json.NewDecoder(f)
	for decoder.More() {
		var result *flatPackage
		if err := decoder.Decode(&result); err != nil {
			t.Errorf("unable to decode output json: %v\n", err)
		}

		if !strings.HasPrefix(result.ID, "@io_bazel_rules_go//stdlib") {
			t.Errorf("ID should be prefixed with @io_bazel_rules_go//stdlib :%v", result)
		}
		if !strings.HasPrefix(result.ExportFile, "__BAZEL_OUTPUT_BASE__") {
			t.Errorf("export file should be prefixed with __BAZEL_OUTPUT_BASE__ :%v", result)
		}
		for _, gofile := range result.GoFiles {
			if !strings.HasPrefix(gofile, "__BAZEL_OUTPUT_BASE__/external/go_sdk") {
				t.Errorf("all go files should be prefixed with __BAZEL_OUTPUT_BASE__/external/go_sdk :%v", result)
			}
		}
	}
}
