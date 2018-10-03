package d

import (
	"fmt"
	"reflect"

	"golang.org/x/tools/go/analysis"
)

// Since the test nogo rule does not explicitly depend on d, we package state
// to assert that this package is only run once.
var numRuns = 0

var Analyzer = &analysis.Analyzer{
	Name:       "d",
	Doc:        "an analyzer that does not depend on other analyzers",
	Run:        run,
	ResultType: reflect.TypeOf(""),
}

func run(pass *analysis.Pass) (interface{}, error) {
	numRuns++
	pass.Report(analysis.Diagnostic{Message: "ran d"})
	if numRuns > 1 {
		return fmt.Sprintf("ran analyzer d %d times", numRuns), nil
	}
	return "d", nil
}
