package tag

import (
	"os/exec"
	"strings"
	"testing"

	"github.com/bazelbuild/rules_go/go/tools/bazel"
)

func Test(t *testing.T) {
	for _, tc := range []struct {
		name, path, want string
	}{
		{
			name: "tag_pure_bin",
			want: "pure",
		}, {
			name: "tag_cgo_bin",
			want: "cgo",
		},
	} {
		t.Run(tc.name, func(t *testing.T) {
			path, ok := bazel.FindBinary("tests/core/cgo", tc.name)
			if !ok {
				t.Fatalf("could not find binary: %s", tc.name)
			}
			out, err := exec.Command(path).Output()
			if err != nil {
				t.Fatal(err)
			}
			got := strings.TrimSpace(string(out))
			if got != tc.want {
				t.Errorf("got %s; want %s", got, tc.want)
			}
		})
	}
}
