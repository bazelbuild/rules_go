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
	"go/parser"
	"go/token"
	"log"
	"os"
	"path/filepath"
	"sort"
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

type Import struct {
	Name string
	Path string
}
type TestCase struct {
	Package string
	Name    string
}

// Cases holds template data.
type Cases struct {
	RunDir     string
	Imports    []*Import
	Tests      []TestCase
	Benchmarks []TestCase
	TestMain   string
	Cover      []*CoverPackage
}

var codeTpl = `
package main
import (
	"flag"
	"log"
	"os"
	"fmt"
	"strconv"
	"testing"
	"testing/internal/testdeps"

{{range $p := .Imports}}
  {{$p.Name}} "{{$p.Path}}"
{{end}}

{{range $p := .Cover}}
	{{$p.Name}} {{$p.Import | printf "%q"}}
{{end}}
)

var allTests = []testing.InternalTest{
{{range .Tests}}
	{"{{.Name}}", {{.Package}}.{{.Name}} },
{{end}}
}

var benchmarks = []testing.InternalBenchmark{
{{range .Benchmarks}}
	{"{{.Name}}", {{.Package}}.{{.Name}} },
{{end}}
}

func testsInShard() []testing.InternalTest {
	totalShards, err := strconv.Atoi(os.Getenv("TEST_TOTAL_SHARDS"))
	if err != nil || totalShards <= 1 {
		return allTests
	}
	shardIndex, err := strconv.Atoi(os.Getenv("TEST_SHARD_INDEX"))
	if err != nil || shardIndex < 0 {
		return allTests
	}
	tests := []testing.InternalTest{}
	for i, t := range allTests {
		if i % totalShards == shardIndex {
			tests = append(tests, t)
		}
	}
	return tests
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

	m := testing.MainStart(testdeps.TestDeps{}, testsInShard(), benchmarks, nil)
	{{if not .TestMain}}
	os.Exit(m.Run())
	{{else}}
	{{.TestMain}}(m)
	{{end}}
}
`

func run(args []string) error {
	// Prepare our flags
	cover := multiFlag{}
	imports := multiFlag{}
	sources := multiFlag{}
	flags := flag.NewFlagSet("generate_test_main", flag.ExitOnError)
	goenv := envFlags(flags)
	runDir := flags.String("rundir", ".", "Path to directory where tests should run.")
	out := flags.String("output", "", "output file to write. Defaults to stdout.")
	flags.Var(&cover, "cover", "Information about a coverage variable")
	flags.Var(&imports, "import", "Packages to import")
	flags.Var(&sources, "src", "Sources to process for tests")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if err := goenv.update(); err != nil {
		return err
	}
	// Process import args
	importMap := map[string]*Import{}
	for _, imp := range imports {
		parts := strings.Split(imp, "=")
		if len(parts) != 2 {
			return fmt.Errorf("Invalid import %q specified", imp)
		}
		i := &Import{Name: parts[0], Path: parts[1]}
		importMap[i.Name] = i
	}
	// Process source args
	sourceList := []string{}
	sourceMap := map[string]string{}
	for _, s := range sources {
		parts := strings.Split(s, "=")
		if len(parts) != 2 {
			return fmt.Errorf("Invalid source %q specified", s)
		}
		sourceList = append(sourceList, parts[1])
		sourceMap[parts[1]] = parts[0]
	}

	// filter our input file list
	bctx := goenv.BuildContext()
	filenames, err := filterFiles(bctx, sourceList)
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
		RunDir: strings.Replace(filepath.FromSlash(*runDir), `\`, `\\`, -1),
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
	pkgs := map[string]bool{}
	for _, f := range filenames {
		parse, err := parser.ParseFile(testFileSet, f, nil, parser.ParseComments)
		if err != nil {
			return fmt.Errorf("ParseFile(%q): %v", f, err)
		}
		pkg := sourceMap[f]
		if strings.HasSuffix(parse.Name.String(), "_test") {
			pkg += "_test"
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
				cases.TestMain = fmt.Sprintf("%s.%s", pkg, fn.Name.Name)
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
				pkgs[pkg] = true
				cases.Tests = append(cases.Tests, TestCase{
					Package: pkg,
					Name:    fn.Name.Name,
				})
			}
			if strings.HasPrefix(fn.Name.Name, "Benchmark") {
				if selExpr.Sel.Name != "B" {
					continue
				}
				pkgs[pkg] = true
				cases.Benchmarks = append(cases.Benchmarks, TestCase{
					Package: pkg,
					Name:    fn.Name.Name,
				})
			}
		}
	}
	// Add only the imports we found tests for
	for pkg := range pkgs {
		cases.Imports = append(cases.Imports, importMap[pkg])
	}
	sort.Slice(cases.Imports, func(i, j int) bool {
		return cases.Imports[i].Name < cases.Imports[j].Name
	})
	tpl := template.Must(template.New("source").Parse(codeTpl))
	if err := tpl.Execute(outFile, &cases); err != nil {
		return fmt.Errorf("template.Execute(%v): %v", cases, err)
	}
	return nil
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}
