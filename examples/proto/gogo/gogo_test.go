package gogo_test

import (
	"testing"

	"github.com/bazelbuild/rules_go/examples/proto/gogo"
)

func TestGoString(t *testing.T) {
	p := gogo.Value{Item: 20}
	got := p.GoString()
	expect := "&gogo.Value{Item: 20,\n}"
	if got != expect {
		t.Errorf("got %q, expect %q", got, expect)
	}
}

func TestSize(t *testing.T) {
	p := gogo.Value{Item: 20}
	got := p.Size()
	expect := 2
	if got != expect {
		t.Errorf("got %v, expect %v", got, expect)
	}
}
