package main

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"
)

func TestRegisterCoverage(t *testing.T) {
	pkgDir, err := ioutil.TempDir("", "cover")
	if err != nil {
		t.Error(err)
	}
	defer os.RemoveAll(pkgDir)
	content := []byte(`package lzma

/* Naming conventions follows the CodeReviewComments in the Go Wiki. */

// ntz32Const is used by the functions NTZ and NLZ.
const ntz32Const = 0x04d7651f
`)
	goFile := filepath.Join(pkgDir, "bitops.go")
	if err := ioutil.WriteFile(goFile, content, 0644); err != nil {
		t.Error(err)
	}

	if err := registerCoverage(goFile, "var", "bitops.go"); err != nil {
		t.Error(err)
	}
	if content, err = ioutil.ReadFile(goFile); err != nil {
		t.Error(err)
	}
	expectedContent := `package lzma

import coverdata "github.com/bazelbuild/rules_go/go/tools/coverdata" /* Naming conventions follows the CodeReviewComments in the Go Wiki. */

// ntz32Const is used by the functions NTZ and NLZ.
const ntz32Const = 0x04d7651f

func init() {
	coverdata.RegisterFile("bitops.go",
		var.Count[:],
		var.Pos[:],
		var.NumStmt[:])
}
`
	contentString := string(content)
	if contentString != expectedContent {
		t.Errorf("expected:\n%v\ngot:\n%v", []byte(expectedContent), []byte(contentString))
	}
}
