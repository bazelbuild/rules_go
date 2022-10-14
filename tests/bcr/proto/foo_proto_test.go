package proto_test

import (
	"testing"

	"example.com/foo_proto"
)

func TestFoo(t *testing.T) {
	msg := &foo_proto.Foo{
		Value: 1,
	}
	if msg.Value != 1 {
		t.Fail()
	}
}
