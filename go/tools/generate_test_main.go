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
			if strings.HasPrefix(fn.Name.Name, "Test") {
				cases.TestNames = append(cases.TestNames, fn.Name.Name)
			}
			if strings.HasPrefix(fn.Name.Name, "Benchmark") {
				cases.BenchmarkNames = append(cases.BenchmarkNames, fn.Name.Name)
			}
		}
	}

	tpl := template.Must(template.New("source").Parse(`
package main
import (
	"os"
	"testing"

{{ if .TestNames }}
        undertest "{{.Package}}"
{{else if .BenchmarkNames }}
        undertest "{{.Package}}"
{{ end }}
)

func everything(pat, str string) (bool, error) {
	return true, nil
}

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
  {{if not .HasTestMain}}
  testing.Main(everything, tests, benchmarks, nil)
  {{else}}
  m := testing.MainStart(everything, tests, benchmarks, nil)
  undertest.TestMain(m)
  {{end}}
}
`))
	if err := tpl.Execute(outFile, &cases); err != nil {
		log.Fatalf("template.Execute(%v): %v", cases, err)
	}
}
