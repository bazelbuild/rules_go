package timeout_test

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel_testing"
)

func TestMain(m *testing.M) {
	bazel_testing.TestMain(m, bazel_testing.Args{
		Main: `
-- BUILD.bazel --
load("@io_bazel_rules_go//go:def.bzl", "go_test")

go_test(
	name = "timeout_test",
	srcs = ["timeout_test.go"],
)
-- timeout_test.go --
package timeout

import "testing"

func TestFoo(t *testing.T) {
	neverTerminates()
}

func neverTerminates() {
	for {}
}
`,
	})
}

func TestTimeout(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("stack traces on timeouts are not yet supported on Windows")
	}

	if err := bazel_testing.RunBazel("test", "//:timeout_test", "--test_timeout=3"); err == nil {
		t.Fatal("expected bazel test to fail")
	} else if exitErr, ok := err.(*bazel_testing.StderrExitError); !ok || exitErr.Err.ExitCode() != 3 {
		t.Fatalf("expected bazel test to fail with exit code 3", err)
	}
	p, err := bazel_testing.BazelOutput("info", "bazel-testlogs")
	if err != nil {
		t.Fatalf("could not find testlogs root: %s", err)
	}
	path := filepath.Join(strings.TrimSpace(string(p)), "timeout_test/test.log")
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("could not read test log: %s", err)
	}

	testLog := string(b)
	if !strings.Contains(testLog, "Received SIGTERM, printing stack traces of all goroutines:") {
		t.Fatalf("test log does not contain expected header:\n%s", testLog)
	}
	if !strings.Contains(testLog, "timeout_test.neverTerminates(") {
		t.Fatalf("test log does not contain expected stack trace:\n%s", testLog)
	}
}
