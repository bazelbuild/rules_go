package external_importmap_dep

import (
	"github.com/bazelbuild/rules_go/tests/core/go_test/external_importmap"
)

type Impl struct{}

func (_ *Impl) DeepCopyObject() external_importmap.Object {
	return nil
}
