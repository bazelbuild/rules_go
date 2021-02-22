package test

import (
	"debug/macho"
	"fmt"
	"os"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel"
)

func openMachO(dir, bin string) (*macho.File, error) {
	bin, ok := bazel.FindBinary(dir, bin)
	if !ok {
		return nil, fmt.Errorf("could not find binary: %s", bin)
	}

	f, err := os.Open(bin)
	if err != nil {
		return nil, err
	}

	return macho.NewFile(f)
}

func TestPIE(t *testing.T) {
	m, err := openMachO("tests/core/go_binary", "hello_pie_bin")
	if err != nil {
		t.Fatal(err)
	}

	if m.Flags&macho.FlagPIE == 0 {
		t.Error("ELF binary is not position-independent.")
	}
}
