package b

import (
	"c"
	"fmt"

	"golang.org/x/tools/go/analysis"
)

var Analyzer = &analysis.Analyzer{
	Name:     "b",
	Doc:      "an analyzer that depends on c.Analyzer",
	Run:      run,
	Requires: []*analysis.Analyzer{c.Analyzer},
}

func run(pass *analysis.Pass) (interface{}, error) {
	pass.Report(analysis.Diagnostic{Message: "ran b"})
	pass.Report(analysis.Diagnostic{Message: fmt.Sprintf("b %s", pass.ResultOf[c.Analyzer].(string))})
	return nil, nil
}
