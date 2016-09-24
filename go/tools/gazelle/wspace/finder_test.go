package wspace

import (
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"
)

type testCase struct {
	dir  string
	want string // "" means should fail
}

func TestFind(t *testing.T) {
	tmp, err := ioutil.TempDir("", "")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmp)
	if err := os.MkdirAll(filepath.Join(tmp, "base", "sub"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := ioutil.WriteFile(filepath.Join(tmp, "base", workspaceFile), []byte{}, 0755); err != nil {
		t.Fatal(err)
	}

	tmpBase := filepath.Join(tmp, "base")

	for _, tc := range []testCase{
		{tmp, ""},
		{tmpBase, tmpBase},
		{filepath.Join(tmpBase, "sub"), tmpBase}} {

		d, err := Find(tc.dir)
		if err != nil {
			if tc.want != "" {
				t.Errorf("Find(%q) want %q, got %v", tc.dir, tc.want, err)
			}
			continue
		}
		if d != tc.want {
			t.Errorf("Find(%q) got %q, want %q", tc.dir, d, tc.want)
		}
	}
}
