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
	"fmt"
	"go/ast"
	"go/build"
	"go/parser"
	"go/token"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"text/template"
)

type CoverFile struct {
	File string
	Var  string
}

type CoverPackage struct {
	Name   string
	Import string
	Files  []CoverFile
}

// Cases holds template data.
type Cases struct {
	Package          string
	RunDir           string
	TestNames        []string
	BenchmarkNames   []string
	HasTestMain      bool
	Version17        bool
	Version18OrNewer bool
	Cover            []*CoverPackage
}

var codeTpl = `
package main
import (
	"flag"
	"log"
	"os"
	"fmt"
{{if .Version17}}
	"regexp"
{{end}}
	"testing"
{{if .Version18OrNewer}}
	"testing/internal/testdeps"
{{end}}

{{if .TestNames}}
	undertest "{{.Package}}"
{{else if .BenchmarkNames}}
	undertest "{{.Package}}"
{{end}}

{{range $p := .Cover}}
	{{$p.Name}} {{$p.Import | printf "%q"}}
{{end}}
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

func coverRegisterAll() testing.Cover {
	coverage := testing.Cover{
		Mode: "set",
		CoveredPackages: "",
		Counters: map[string][]uint32{},
		Blocks: map[string][]testing.CoverBlock{},
	}
{{range $p := .Cover}}
	//{{$p.Import}}
{{range $v := $p.Files}}
	{{$var := printf "%s.%s" $p.Name $v.Var}}
	coverRegisterFile(&coverage, {{$v.File | printf "%q"}}, {{$var}}.Count[:], {{$var}}.Pos[:], {{$var}}.NumStmt[:])
{{end}}
{{end}}
	return coverage
}

func coverRegisterFile(coverage *testing.Cover, fileName string, counter []uint32, pos []uint32, numStmts []uint16) {
	if 3*len(counter) != len(pos) || len(counter) != len(numStmts) {
		panic("coverage: mismatched sizes")
	}
	if coverage.Counters[fileName] != nil {
		// Already registered.
		fmt.Printf("Already covered %s\n", fileName)
		return
	}
	coverage.Counters[fileName] = counter
	block := make([]testing.CoverBlock, len(counter))
	for i := range counter {
		block[i] = testing.CoverBlock{
			Line0: pos[3*i+0],
			Col0: uint16(pos[3*i+2]),
			Line1: pos[3*i+1],
			Col1: uint16(pos[3*i+2]>>16),
			Stmts: numStmts[i],
		}
	}
	coverage.Blocks[fileName] = block
}

func main() {
	// Check if we're being run by Bazel and change directories if so.
	// TEST_SRCDIR is set by the Bazel test runner, so that makes a decent proxy.
	if _, ok := os.LookupEnv("TEST_SRCDIR"); ok {
		if err := os.Chdir("{{.RunDir}}"); err != nil {
			log.Fatalf("could not change to test directory: %v", err)
		}
	}

	if filter := os.Getenv("TESTBRIDGE_TEST_ONLY"); filter != "" {
		if f := flag.Lookup("test.run"); f != nil {
			f.Value.Set(filter)
		}
	}

	coverage := coverRegisterAll()
	if len(coverage.Counters) > 0 {
		testing.RegisterCover(coverage)
	}

{{if .Version18OrNewer}}
	m := testing.MainStart(testdeps.TestDeps{}, tests, benchmarks, nil)
	{{if not .HasTestMain}}
	os.Exit(m.Run())
	{{else}}
	undertest.TestMain(m)
	{{end}}
{{else if .Version17}}
	{{if not .HasTestMain}}
	testing.Main(regexp.MatchString, tests, benchmarks, nil)
	{{else}}
	m := testing.MainStart(regexp.MatchString, tests, benchmarks, nil)
	undertest.TestMain(m)
	{{end}}
{{end}}
}
`

func run(args []string) error {
	// Prepare our flags
	cover := multiFlag{}
	flags := flag.NewFlagSet("generate_test_main", flag.ExitOnError)
	pkg := flags.String("package", "", "package from which to import test methods.")
	runDir := flags.String("rundir", ".", "Path to directory where tests should run.")
	out := flags.String("output", "", "output file to write. Defaults to stdout.")
	tags := flags.String("tags", "", "Only pass through files that match these tags.")
	flags.Var(&cover, "cover", "Information about a coverage variable")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *pkg == "" {
		return fmt.Errorf("must set --package.")
	}
	// filter our input file list
	bctx := build.Default
	bctx.CgoEnabled = true
	bctx.BuildTags = strings.Split(*tags, ",")
	filenames, err := filterFiles(bctx, flags.Args())
	if err != nil {
		return err
	}

	outFile := os.Stdout
	if *out != "" {
		var err error
		outFile, err = os.Create(*out)
		if err != nil {
			return fmt.Errorf("os.Create(%q): %v", *out, err)
		}
		defer outFile.Close()
	}

	cases := Cases{
		Package: *pkg,
		RunDir:  filepath.FromSlash(*runDir),
	}
	covered := map[string]*CoverPackage{}
	for _, c := range cover {
		bits := strings.SplitN(c, "=", 3)
		if len(bits) != 3 {
			return fmt.Errorf("Invalid cover variable arg, expected var=file=package got %s", c)
		}
		importPath := bits[2]
		pkg, found := covered[importPath]
		if !found {
			pkg = &CoverPackage{
				Name:   fmt.Sprintf("covered%d", len(covered)),
				Import: importPath,
			}
			covered[importPath] = pkg
			cases.Cover = append(cases.Cover, pkg)
		}
		pkg.Files = append(pkg.Files, CoverFile{
			File: bits[1],
			Var:  bits[0],
		})
	}

	testFileSet := token.NewFileSet()
	for _, f := range filenames {
		parse, err := parser.ParseFile(testFileSet, f, nil, parser.ParseComments)
		if err != nil {
			return fmt.Errorf("ParseFile(%q): %v", f, err)
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

	goVersion, err := parseVersion(runtime.Version())
	if err != nil {
		return err
	}
	if goVersion.Less(version{1, 7}) {
		return fmt.Errorf("go version %s not supported", runtime.Version())
	} else if goVersion.Less(version{1, 8}) {
		cases.Version17 = true
	} else {
		cases.Version18OrNewer = true
	}

	tpl := template.Must(template.New("source").Parse(codeTpl))
	if err := tpl.Execute(outFile, &cases); err != nil {
		return fmt.Errorf("template.Execute(%v): %v", cases, err)
	}
	return nil
}

type version []int

func parseVersion(s string) (version, error) {
	strParts := strings.Split(s[len("go"):], ".")
	intParts := make([]int, len(strParts))
	for i, s := range strParts {
		v, err := strconv.Atoi(s)
		if err != nil {
			return nil, fmt.Errorf("non-number in go version: %s", s)
		}
		intParts[i] = v
	}
	return intParts, nil
}

func (x version) Less(y version) bool {
	n := len(x)
	if len(y) < n {
		n = len(y)
	}
	for i := 0; i < n; i++ {
		cmp := x[i] - y[i]
		if cmp != 0 {
			return cmp < 0
		}
	}
	return len(x) < len(y)
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}
