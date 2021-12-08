package cc_libs_test

import (
	"bytes"
	"github.com/bazelbuild/rules_go/go/tools/bazel"
	"io/ioutil"
	"testing"
)

// A distinctive substring contained in every absolute path pointing into the
// Bazel cache.
const execPathIndicator = "/execroot/io_bazel_rules_go"

func verifyNoCachePaths(t *testing.T, shortPath string) {
	binPath, err := bazel.Runfile(shortPath)
	if err != nil {
		t.Error(err)
	}
	binBytes, err := ioutil.ReadFile(binPath)
	if err != nil {
		t.Error(err)
	}
	if pos := bytes.Index(binBytes, []byte(execPathIndicator)); pos != -1 {
		begin := pos - 150
		if begin < 0 {
			begin = 0
		}
		end := pos + 150
		if end > len(binBytes) {
			end = len(binBytes)
		}
		t.Errorf("%s leaks an absolute path:\n%q", shortPath, binBytes[begin:end])
	}
}
