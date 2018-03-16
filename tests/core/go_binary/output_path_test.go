package outpath_opts_test

import (
	"flag"
	"testing"
)

var (
	plain  = flag.String("plain", "", "")
	noMode = flag.String("no_mode", "", "")
	noExt  = flag.String("no_ext", "", "")
)

func TestPathOpts(t *testing.T) {
	checks := []struct {
		label, got, want string
	}{
		{
			label: ":hello_plain",
			got:   *plain,
			want:  "tests/core/go_binary/windows_amd64_pure_stripped/hello_plain.exe",
		},
		{
			label: ":hello_no_mode",
			got:   *noMode,
			want:  "tests/core/go_binary/hello_no_mode.exe",
		},
		{
			label: ":hello_no_ext",
			got:   *noExt,
			want:  "tests/core/go_binary/windows_amd64_pure_stripped/hello_no_ext",
		},
	}

	for _, c := range checks {
		if c.got != c.want {
			t.Errorf("incorrect output path for label %q\nExpected %v\nGot      %v", c.label, c.want, c.got)
		}
	}
}
