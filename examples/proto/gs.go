package proto

import (
	"fmt"

	"github.com/bazelbuild/rules_go/examples/proto/gostyle"
)

func DoGoStyle(g *gostyle.GoStyleObject) error {
	if g != nil {
		return fmt.Errorf("got nil")
	}
	return nil
}
