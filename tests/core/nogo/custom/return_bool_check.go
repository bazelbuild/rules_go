// returnboolcheck checks for functions that return bool.
package returnboolcheck

import (
	"go/ast"

	"github.com/bazelbuild/rules_go/go/tools/analysis"
)

var Analysis = &analysis.Analysis{Name: "return_bool_check", Run: run}

func init() {
	analysis.Register(Analysis)
}

func run(p *analysis.Package) (*analysis.Result, error) {
	var findings []*analysis.Finding
	for _, f := range p.Files {
		ast.Inspect(f, func(n ast.Node) bool {
			switch n := n.(type) {
			case *ast.FuncDecl:
				if results := n.Type.Results; results != nil {
					for _, f := range results.List {
						if ident, ok := f.Type.(*ast.Ident); ok && ident.Name == "bool" {
							findings = append(findings, &analysis.Finding{
								Pos:     n.Pos(),
								End:     n.End(),
								Message: "function must not return bool",
							})
						}
					}
				}
			}
			return true
		})
	}

	return &analysis.Result{Findings: findings}, nil
}
