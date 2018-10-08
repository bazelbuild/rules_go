// boolreturn checks for functions with boolean return values.
package boolreturn

import (
	"go/ast"
	"go/types"

	"golang.org/x/tools/go/analysis"
)

const doc = `report functions that return booleans

The boolreturn analyzer reports functions that return booleans.`

var Analyzer = &analysis.Analyzer{
	Name: "boolreturn",
	Run:  run,
	Doc:  doc,
}

func run(pass *analysis.Pass) (interface{}, error) {
	for _, f := range pass.Files {
		// TODO(samueltan): use package inspector once the latest golang.org/x/tools
		// changes are pulled into this branch (see #1755).
		ast.Inspect(f, func(n ast.Node) bool {
			switch n := n.(type) {
			case *ast.FuncDecl:
				results := pass.TypesInfo.Defs[n.Name].Type().(*types.Signature).Results()
				for i := 0; i < results.Len(); i++ {
					if results.At(i).Type() == types.Typ[types.Bool] {
						pass.Reportf(n.Pos(), "function must not return bool")
					}
				}
			}
			return true
		})
	}
	return nil, nil
}
