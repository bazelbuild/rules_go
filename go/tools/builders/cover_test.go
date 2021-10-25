package main

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"
)

type test struct {
	name string
	in   string
	out  string
}

var tests = []test{
	{
		name: "no imports",
		in: `package main
`,
		out: `package main; import "github.com/bazelbuild/rules_go/go/tools/coverdata"

func init() {
	coverdata.RegisterFile("srcName",
		varName.Count[:],
		varName.Pos[:],
		varName.NumStmt[:])
}
`,
	},
	{
		name: "other imports",
		in: `package main

import (
	"os"
)
`,
		out: `package main; import "github.com/bazelbuild/rules_go/go/tools/coverdata"

import (
	"os"
)

func init() {
	coverdata.RegisterFile("srcName",
		varName.Count[:],
		varName.Pos[:],
		varName.NumStmt[:])
}
`,
	},
	{
		name: "existing import",
		in: `package main

import "github.com/bazelbuild/rules_go/go/tools/coverdata"
`,
		out: `package main

import "github.com/bazelbuild/rules_go/go/tools/coverdata"

func init() {
	coverdata.RegisterFile("srcName",
		varName.Count[:],
		varName.Pos[:],
		varName.NumStmt[:])
}
`,
	},
	{
		name: "existing _ import",
		in: `package main

import _ "github.com/bazelbuild/rules_go/go/tools/coverdata"
`,
		out: `package main

import coverdata "github.com/bazelbuild/rules_go/go/tools/coverdata"

func init() {
	coverdata.RegisterFile("srcName",
		varName.Count[:],
		varName.Pos[:],
		varName.NumStmt[:])
}
`,
	},
	{
		name: "existing renamed import",
		in: `package main

import cover0 "github.com/bazelbuild/rules_go/go/tools/coverdata"
`,
		out: `package main

import cover0 "github.com/bazelbuild/rules_go/go/tools/coverdata"

func init() {
	cover0.RegisterFile("srcName",
		varName.Count[:],
		varName.Pos[:],
		varName.NumStmt[:])
}
`,
	},
}

func TestRegisterCoverage(t *testing.T) {
	var filename = filepath.Join(t.TempDir(), "test_input.go")
	for _, test := range tests {
		if err := ioutil.WriteFile(filename, []byte(test.in), 0666); err != nil {
			t.Errorf("writing input file: %v", err)
			return
		}
		err := registerCoverage(filename, "varName", "srcName")
		if err != nil {
			t.Errorf("%q: %+v", test.name, err)
			continue
		}
		coverSrc, err := os.ReadFile(filename)
		if err != nil {
			t.Errorf("%q: %+v", test.name, err)
			continue
		}
		if got, want := string(coverSrc), test.out; got != want {
			t.Errorf("%q: got %v, want %v", test.name, got, want)
		}
	}
}
