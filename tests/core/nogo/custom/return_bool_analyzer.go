// returnboolanalyzer checks for functions that return bool.
package returnboolanalyzer

import (
	"go/ast"

	"golang.org/x/tools/go/analysis"
)

const doc = `report functions that return booleans

The return_bool_analyzer analyzer reports functions that return booleans.`

var Analyzer = &analysis.Analyzer{
	Name: "return_bool_analyzer",
	Run:  run,
	Doc:  doc,
}

func run(pass *analysis.Pass) (interface{}, error) {
	for _, f := range pass.Files {
		ast.Inspect(f, func(n ast.Node) bool {
			switch n := n.(type) {
			case *ast.FuncDecl:
				if results := n.Type.Results; results != nil {
					for _, f := range results.List {
						if ident, ok := f.Type.(*ast.Ident); ok && ident.Name == "bool" {
							pass.Reportf(n.Pos(), "function must not return bool")
						}
					}
				}
			}
			return true
		})
	}
	return nil, nil
}
