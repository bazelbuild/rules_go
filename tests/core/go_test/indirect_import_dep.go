package indirect_import_dep

import "github.com/bazelbuild/rules_go/tests/core/go_test/indirect_import"

func GetX() string {
	return indirect_import.X
}
