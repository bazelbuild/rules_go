// importfmtanalyzer checks for functions named "Foo".
// It has the same package name as another check to test the checks with
// the same package name do not conflict.
package importfmtanalyzer

import (
	"go/ast"

	"golang.org/x/tools/go/analysis"
)

const doc = `report calls of functions named "Foo"

The foo_func_analyzer analyzer reports calls to functions that are
named "Foo".`

var Analyzer = &analysis.Analyzer{
	Name: "foo_func_analyzer",
	Run:  run,
	Doc:  doc,
}

func run(pass *analysis.Pass) (interface{}, error) {
	for _, f := range pass.Files {
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
