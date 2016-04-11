package main

import (
	"io/ioutil"
	"os"
	"testing"
)

func TestExtract(t *testing.T) {
	for _, spec := range []struct {
		src  string
		want string
	}{
		// These example inputs also illustrate the reason why we
		// cannot simply replace extract_package with sed(1) or awk(1).
		{
			src:  `package main`,
			want: "main",
		},
		{
			src:  `package /* package another */ example // package yetanother`,
			want: "example",
		},
	} {
		f, err := ioutil.TempFile(os.Getenv("TEST_TMPDIR"), "example-go-src")
		if err != nil {
			t.Fatal(err)
		}
		defer os.Remove(f.Name())
		if err := ioutil.WriteFile(f.Name(), []byte(spec.src), 0644); err != nil {
			t.Fatal(err)
		}

		name, err := extract(f.Name())
		if err != nil {
			t.Errorf("extract(%q) failed with %v; want success; content = %q", f.Name(), err, spec.src)
		}
		if got, want := name, spec.want; got != want {
			t.Errorf("extract(%q) = %q; want %q; content = %q", f.Name(), got, want, spec.src)
		}
	}
}
