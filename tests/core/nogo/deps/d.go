package d

import (
	"go/token"
	"reflect"

	"golang.org/x/tools/go/analysis"
)

var Analyzer = &analysis.Analyzer{
	Name:       "d",
	Doc:        "an analyzer that does not depend on other analyzers",
	Run:        run,
	ResultType: reflect.TypeOf(""),
}

func run(pass *analysis.Pass) (interface{}, error) {
	pass.Reportf(token.NoPos, "this should not be printed")
	return "d", nil
}
