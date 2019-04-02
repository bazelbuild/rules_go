package main

import (
	"os/exec"
	"strings"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel"
)

func TestStamp(t *testing.T) {
	bin, ok := bazel.FindBinary("tests/core/go_binary", "stamp_bin")
	if !ok {
		t.Error("could not find stamp_bin")
	}
	out, err := exec.Command(bin).Output()
	if err != nil {
		t.Fatal(err)
	}

	got := strings.TrimSpace(string(out))
	want := `Bin=Bin
Embed=Embed
DepSelf=DepSelf
DepBin=DepBin`
	if got != want {
		t.Errorf("got:\n%s\nwant:\n%s", got, want)
	}
}
