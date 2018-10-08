package b

import (
	"c"
	"go/token"

	"golang.org/x/tools/go/analysis"
)

var Analyzer = &analysis.Analyzer{
	Name:     "b",
	Doc:      "an analyzer that depends on c.Analyzer",
	Run:      run,
	Requires: []*analysis.Analyzer{c.Analyzer},
}

func run(pass *analysis.Pass) (interface{}, error) {
	pass.Reportf(token.NoPos, "b %s", pass.ResultOf[c.Analyzer])
	return nil, nil
}
