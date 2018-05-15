// foofunccheck checks for functions named "Foo".
package foofunccheck

import (
	"go/ast"

	"github.com/bazelbuild/rules_go/go/tools/analysis"
)

var Analysis = &analysis.Analysis{Name: "foo_func_check", Run: run}

func init() {
	analysis.Register(Analysis)
}

func run(p *analysis.Package) (*analysis.Result, error) {
	var findings []*analysis.Finding
	for _, f := range p.Files {
		ast.Inspect(f, func(n ast.Node) bool {
			switch n := n.(type) {
			case *ast.FuncDecl:
				if n.Name.Name == "Foo" {
					findings = append(findings, &analysis.Finding{
						Pos:     n.Pos(),
						End:     n.End(),
						Message: "function must not be named Foo",
					})
				}
				return true
			}
			return true
		})
	}

	return &analysis.Result{Findings: findings}, nil
}
