/* Copyright 2016 The Bazel Authors. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// Bare bones Go testing support for Bazel.

package main

import (
	"flag"
	"go/ast"
	"go/parser"
	"go/token"
	"log"
	"os"
	"strings"
	"text/template"
)

// Cases holds template data.
type Cases struct {
	Package        string
	RunDir         string
	TestNames      []string
	BenchmarkNames []string
	HasTestMain    bool
}

func main() {
	pkg := flag.String("package", "", "package from which to import test methods.")
	out := flag.String("output", "", "output file to write. Defaults to stdout.")
	flag.Parse()

	if *pkg == "" {
		log.Fatal("must set --package.")
	}

	outFile := os.Stdout
	if *out != "" {
		var err error
		outFile, err = os.Create(*out)
		if err != nil {
			log.Fatalf("os.Create(%q): %v", *out, err)
		}
		defer outFile.Close()
	}

	cases := Cases{
		Package: *pkg,
		RunDir:  os.Getenv("RUNDIR"),
	}
	testFileSet := token.NewFileSet()
	for _, f := range flag.Args() {
		parse, err := parser.ParseFile(testFileSet, f, nil, parser.ParseComments)
		if err != nil {
			log.Fatalf("ParseFile(%q): %v", f, err)
		}

		for _, d := range parse.Decls {
			fn, ok := d.(*ast.FuncDecl)
			if !ok {
				continue
			}
			if fn.Recv != nil {
				continue
			}
			if fn.Name.Name == "TestMain" {
				// TestMain is not, itself, a test
				cases.HasTestMain = true
				continue
			}

			// Here we check the signature of the Test* function. To
			// be considered a test:

			// 1. The function should have a single argument.
			if len(fn.Type.Params.List) != 1 {
				continue
			}

			// 2. The function should return nothing.
			if fn.Type.Results != nil {
				continue
			}

			// 3. The only parameter should have a type identified as
			//    *<something>.T
			starExpr, ok := fn.Type.Params.List[0].Type.(*ast.StarExpr)
			if !ok {
				continue
			}
			selExpr, ok := starExpr.X.(*ast.SelectorExpr)
			if !ok {
				continue
			}

			// We do not descriminate on the referenced type of the
			// parameter being *testing.T. Instead we assert that it
			// should be *<something>.T. This is because the import
			// could have been aliased as a different identifier.

			if strings.HasPrefix(fn.Name.Name, "Test") {
				if selExpr.Sel.Name != "T" {
					continue
				}
				cases.TestNames = append(cases.TestNames, fn.Name.Name)
			}
			if strings.HasPrefix(fn.Name.Name, "Benchmark") {
				if selExpr.Sel.Name != "B" {
					continue
				}
				cases.BenchmarkNames = append(cases.BenchmarkNames, fn.Name.Name)
			}
		}
	}

	tpl := template.Must(template.New("source").Parse(`
package main
import (
	"flag"
	"os"
	"testing"
	"testing/internal/testdeps"

{{ if .TestNames }}
	undertest "{{.Package}}"
{{else if .BenchmarkNames }}
	undertest "{{.Package}}"
{{ end }}
)

var tests = []testing.InternalTest{
{{range .TestNames}}
	{"{{.}}", undertest.{{.}} },
{{end}}
}

var benchmarks = []testing.InternalBenchmark{
{{range .BenchmarkNames}}
	{"{{.}}", undertest.{{.}} },
{{end}}
}

func main() {
	os.Chdir("{{.RunDir}}")
	if filter := os.Getenv("TESTBRIDGE_TEST_ONLY"); filter != "" {
		if f := flag.Lookup("test.run"); f != nil {
			f.Value.Set(filter)
		}
	}

	m := testing.MainStart(testdeps.TestDeps{}, tests, benchmarks, nil)
{{if not .HasTestMain}}
	os.Exit(m.Run())
{{else}}
	undertest.TestMain(m)
{{end}}
}
`))
	if err := tpl.Execute(outFile, &cases); err != nil {
		log.Fatalf("template.Execute(%v): %v", cases, err)
	}
}
