// visibility looks for visibility annotations on functions and
// checks they are only called from packages allowed to call them.
package visibility

import (
	"encoding/gob"
	"go/ast"
	"regexp"

	"golang.org/x/tools/go/analysis"
	"golang.org/x/tools/go/ast/inspector"
)

var Analyzer = &analysis.Analyzer{
	Name: "visibility",
	Run:  run,
	Doc: `enforce visibility requirements for functions

The visibility analyzer reads visibility annotations on functions and
checks that packages that call those functions are allowed to do so.
`,
	FactTypes: []analysis.Fact{(*VisibilityFact)(nil)},
}

type VisibilityFact struct {
	Paths []string
}

func (_ *VisibilityFact) AFact() {} // dummy method to satisfy interface

func init() { gob.Register((*VisibilityFact)(nil)) }

var visibilityRegexp = regexp.MustCompile(`visibility:([^\s]+)`)

func run(pass *analysis.Pass) (interface{}, error) {
	in := inspector.New(pass.Files)

	// Find visibility annotations on function declarations.
	in.Nodes([]ast.Node{(*ast.FuncDecl)(nil)}, func(n ast.Node, push bool) (prune bool) {
		if !push {
			return false
		}

		fn := n.(*ast.FuncDecl)

		if fn.Doc == nil {
			return true
		}
		obj := pass.TypesInfo.ObjectOf(fn.Name)
		if obj == nil {
			return true
		}
		doc := fn.Doc.Text()

		if matches := visibilityRegexp.FindAllStringSubmatch(doc, -1); matches != nil {
			fact := &VisibilityFact{Paths: make([]string, len(matches))}
			for i, m := range matches {
				fact.Paths[i] = m[1]
			}
			pass.ExportObjectFact(obj, fact)
		}

		return true
	})

	// Find calls that may be affected by visibility declarations.
	in.Nodes([]ast.Node{(*ast.CallExpr)(nil)}, func(n ast.Node, push bool) (prune bool) {
		if !push {
			return false
		}

		callee, ok := n.(*ast.CallExpr).Fun.(*ast.SelectorExpr)
		if !ok {
			return false
		}
		obj := pass.TypesInfo.ObjectOf(callee.Sel)
		if obj == nil {
			return false
		}
		var fact VisibilityFact
		if ok := pass.ImportObjectFact(obj, &fact); !ok {
			return false
		}
		visible := false
		for _, path := range fact.Paths {
			if path == pass.Pkg.Path() {
				visible = true
				break
			}
		}
		if !visible {
			pass.Reportf(callee.Pos(), "function %s is not visible in this package", callee.Sel.Name)
		}

		return false
	})

	return nil, nil
}
