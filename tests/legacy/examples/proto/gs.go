package proto

import (
	"fmt"

	"github.com/bazelbuild/rules_go/examples/proto/gostyle"
	lib_proto "github.com/bazelbuild/rules_go/examples/proto/lib/lib_proto"
)

func DoGoStyle(g *gostyle.GoStyleObject) error {
	if g == nil {
		return fmt.Errorf("got nil")
	}
	return nil
}

func DoMultiProtos(a *lib_proto.LibObject, b *lib_proto.LibObject2) error {
	if a == nil || b == nil {
		return fmt.Errorf("got nil")
	}
	return nil
}
