package a

import (
	"c"
	"go/token"

	"golang.org/x/tools/go/analysis"
)

var Analyzer = &analysis.Analyzer{
	Name:     "a",
	Doc:      "an analyzer that depends on c.Analyzer",
	Run:      run,
	Requires: []*analysis.Analyzer{c.Analyzer},
}

func run(pass *analysis.Pass) (interface{}, error) {
	pass.Reportf(token.NoPos, "a %s", pass.ResultOf[c.Analyzer])
	return nil, nil
}
