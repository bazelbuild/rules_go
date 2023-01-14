package runfiles

import (
	"os"
	"testing"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

func TestRunfilesApparent(t *testing.T) {
	path, err := runfiles.Rlocation("other_module/bar.txt")
	if err != nil {
		t.Fatalf("runfiles.Path: %v", err)
	}
	assertRunfile(t, path)
}

func TestRunfilesApparentSourceRepositoryOption(t *testing.T) {
	r, err := runfiles.New(runfiles.SourceRepo(runfiles.CurrentRepository()))
	if err != nil {
		t.Fatalf("runfiles.New: %v", err)
	}
	path, err := r.Rlocation("other_module/bar.txt")
	if err != nil {
		t.Fatalf("runfiles.Path: %v", err)
	}
	assertRunfile(t, path)
}

func TestRunfilesApparentWithSourceRepository(t *testing.T) {
	r, err := runfiles.New()
	if err != nil {
		t.Fatalf("runfiles.New: %v", err)
	}
	r = r.WithSourceRepo(runfiles.CurrentRepository())
	path, err := r.Rlocation("other_module/bar.txt")
	if err != nil {
		t.Fatalf("runfiles.Path: %v", err)
	}
	assertRunfile(t, path)
}

func TestRunfilesFromApparent(t *testing.T) {
	path, err := runfiles.RlocationFrom("other_module/bar.txt", runfiles.CurrentRepository())
	if err != nil {
		t.Fatalf("runfiles.Path: %v", err)
	}
	assertRunfile(t, path)
}

func TestRunfilesCanonical(t *testing.T) {
	path, err := runfiles.Rlocation(os.Args[1])
	if err != nil {
		t.Fatalf("runfiles.Path: %v", err)
	}
	assertRunfile(t, path)
}

func assertRunfile(t *testing.T, path string) {
	content, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("os.ReadFile: %v", err)
	}
	if string(content) != "hello\n" {
		t.Fatalf("got %q; want %q", content, "hello\n")
	}
}
