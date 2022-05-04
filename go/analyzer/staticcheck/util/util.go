package util

import (
	"fmt"

	"golang.org/x/tools/go/analysis"
	"honnef.co/go/tools/analysis/lint"
	"honnef.co/go/tools/quickfix"
	"honnef.co/go/tools/simple"
	"honnef.co/go/tools/staticcheck"
	"honnef.co/go/tools/stylecheck"
)

var Analyzers = func() map[string]*analysis.Analyzer {
	resMap := make(map[string]*analysis.Analyzer)

	for _, analyzers := range [][]*lint.Analyzer{
		quickfix.Analyzers,
		simple.Analyzers,
		staticcheck.Analyzers,
		stylecheck.Analyzers,
	} {
		for _, a := range analyzers {
			resMap[a.Analyzer.Name] = a.Analyzer
		}
	}

	return resMap
}()

func FindAnalyzerByName(name string) *analysis.Analyzer {
	if a, ok := Analyzers[name]; ok {
		return a
	}

	panic(fmt.Sprintf("not a valid staticcheck analyzer: %s", name))
}
