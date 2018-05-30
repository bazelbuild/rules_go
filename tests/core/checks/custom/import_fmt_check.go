// importfmtcheck checks for the import of package fmt.
package importfmtcheck

import (
	"go/ast"

	"github.com/bazelbuild/rules_go/go/tools/analysis"
)

var Analysis = &analysis.Analysis{Name: "import_fmt_check", Run: run}

func init() {
	analysis.Register(Analysis)
}

func run(p *analysis.Package) (*analysis.Result, error) {
	var findings []*analysis.Finding
	for _, f := range p.Files {
		ast.Inspect(f, func(n ast.Node) bool {
			switch n := n.(type) {
			case *ast.ImportSpec:
				if n.Path.Value == "\"fmt\"" {
					findings = append(findings, &analysis.Finding{
						Pos:     n.Pos(),
						End:     n.End(),
						Message: "package fmt must not be imported",
					})
				}
				return true
			}
			return true
		})
	}

	return &analysis.Result{Findings: findings}, nil
}
