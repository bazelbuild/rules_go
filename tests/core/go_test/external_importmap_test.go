package external_importmap_test

import (
	"github.com/bazelbuild/rules_go/tests/core/go_test/external_importmap"
	"github.com/bazelbuild/rules_go/tests/core/go_test/external_importmap_dep"
)

var _ external_importmap.Object = &external_importmap_dep.Impl{}

// Test passes if it compiles.
