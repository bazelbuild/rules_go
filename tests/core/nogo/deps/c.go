package c

import (
	"d"
	"fmt"
	"go/token"
	"reflect"

	"golang.org/x/tools/go/analysis"
)

var Analyzer = &analysis.Analyzer{
	Name:       "c",
	Doc:        "an analyzer that depends on d.Analyzer",
	Run:        run,
	Requires:   []*analysis.Analyzer{d.Analyzer},
	ResultType: reflect.TypeOf(""),
}

func run(pass *analysis.Pass) (interface{}, error) {
	pass.Reportf(token.NoPos, "only printed once")
	return fmt.Sprintf("c %s", pass.ResultOf[d.Analyzer]), nil
}
