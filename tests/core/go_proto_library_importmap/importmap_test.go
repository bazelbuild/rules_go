package importmap_test

import (
	"reflect"
	"testing"

	foo "github.com/bazelbuild/rules_go/tests/core/go_proto_library_importmap"
)

func TestImportMap(t *testing.T) {
	got := reflect.TypeOf(foo.Foo{}).PkgPath()
	want := "never/gonna/give/you/up"
	if got != want {
		t.Errorf("got %q; want %q", got, want)
	}
}
