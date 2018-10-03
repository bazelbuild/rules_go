// importfmtanalyzer checks for the import of package fmt.
package importfmtanalyzer

import (
	"go/ast"

	"golang.org/x/tools/go/analysis"
)

const doc = `report imports of package fmt

The import_fmt_analyzer analyzer reports imports of package fmt.`

var Analyzer = &analysis.Analyzer{
	Name: "import_fmt_analyzer",
	Run:  run,
	Doc:  doc,
}

func run(pass *analysis.Pass) (interface{}, error) {
	for _, f := range pass.Files {
		ast.Inspect(f, func(n ast.Node) bool {
			switch n := n.(type) {
			case *ast.ImportSpec:
				if n.Path.Value == "\"fmt\"" {
					pass.Reportf(n.Pos(), "package fmt must not be imported")
				}
				return true
			}
			return true
		})
	}
	return nil, nil
}
