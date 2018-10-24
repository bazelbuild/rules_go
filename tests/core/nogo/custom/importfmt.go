// importfmt checks for the import of package fmt.
package importfmt

import (
	"go/ast"
	"strconv"

	"golang.org/x/tools/go/analysis"
)

const doc = `report imports of package fmt

The importfmt analyzer reports imports of package fmt.`

var Analyzer = &analysis.Analyzer{
	Name: "importfmt",
	Run:  run,
	Doc:  doc,
}

func run(pass *analysis.Pass) (interface{}, error) {
	for _, f := range pass.Files {
		// TODO(samueltan): use package inspector once the latest golang.org/x/tools
		// changes are pulled into this branch (see #1755).
		ast.Inspect(f, func(n ast.Node) bool {
			switch n := n.(type) {
			case *ast.ImportSpec:
				if path, _ := strconv.Unquote(n.Path.Value); path == "fmt" {
					pass.Reportf(n.Pos(), "package fmt must not be imported")
				}
				return true
			}
			return true
		})
	}
	return nil, nil
}
