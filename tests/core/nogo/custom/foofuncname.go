// importfmt checks for functions named "Foo".
// It has the same package name as another check to test the checks with
// the same package name do not conflict.
package importfmt

import (
	"go/ast"

	"golang.org/x/tools/go/analysis"
)

const doc = `report calls of functions named "Foo"

The foofuncname analyzer reports calls to functions that are
named "Foo".`

var Analyzer = &analysis.Analyzer{
	Name: "foofuncname",
	Run:  run,
	Doc:  doc,
}

func run(pass *analysis.Pass) (interface{}, error) {
	for _, f := range pass.Files {
		// TODO(samueltan): use package inspector once the latest golang.org/x/tools
		// changes are pulled into this branch  (see #1755).
		ast.Inspect(f, func(n ast.Node) bool {
			switch n := n.(type) {
			case *ast.FuncDecl:
				if n.Name.Name == "Foo" {
					pass.Reportf(n.Pos(), "function must not be named Foo")
				}
				return true
			}
			return true
		})
	}
	return nil, nil
}
