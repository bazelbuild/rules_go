package a

import (
	"c"
	"fmt"

	"golang.org/x/tools/go/analysis"
)

var Analyzer = &analysis.Analyzer{
	Name:     "a",
	Doc:      "an analyzer that depends on c.Analyzer",
	Run:      run,
	Requires: []*analysis.Analyzer{c.Analyzer},
}

func run(pass *analysis.Pass) (interface{}, error) {
	pass.Report(analysis.Diagnostic{Message: "ran a"})
	pass.Report(analysis.Diagnostic{Message: fmt.Sprintf("a %s", pass.ResultOf[c.Analyzer].(string))})
	return nil, nil
}
