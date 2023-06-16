/* Copyright 2018 The Bazel Authors. All rights reserved.

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

// Loads and runs registered analyses on a well-typed Go package.
// The code in this file is combined with the code generated by
// generate_nogo_main.go.

package main

import (
	"bytes"
	"encoding/gob"
	"errors"
	"flag"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"go/types"
	"io"
	"log"
	"os"
	"reflect"
	"regexp"
	"sort"
	"strings"
	"sync"

	"golang.org/x/tools/go/analysis"
	"golang.org/x/tools/go/gcexportdata"
	"golang.org/x/tools/internal/facts"
)

const nogoBaseConfigName = "_base"

func init() {
	if err := analysis.Validate(analyzers); err != nil {
		log.Fatal(err)
	}
}

var typesSizes = types.SizesFor("gc", os.Getenv("GOARCH"))

func main() {
	log.SetFlags(0) // no timestamp
	log.SetPrefix("nogo: ")
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}

// run returns an error if there is a problem loading the package or if any
// analysis fails.
func run(args []string) error {
	args, _, err := expandParamsFiles(args)
	if err != nil {
		return fmt.Errorf("error reading paramfiles: %v", err)
	}

	factMap := factMultiFlag{}
	flags := flag.NewFlagSet("nogo", flag.ExitOnError)
	flags.Var(&factMap, "fact", "Import path and file containing facts for that library, separated by '=' (may be repeated)'")
	importcfg := flags.String("importcfg", "", "The import configuration file")
	packagePath := flags.String("p", "", "The package path (importmap) of the package being compiled")
	xPath := flags.String("x", "", "The archive file where serialized facts should be written")
	flags.Parse(args)
	srcs := flags.Args()

	packageFile, importMap, err := readImportCfg(*importcfg)
	if err != nil {
		return fmt.Errorf("error parsing importcfg: %v", err)
	}

	diagnostics, facts, err := checkPackage(analyzers, *packagePath, packageFile, importMap, factMap, srcs)
	if err != nil {
		return fmt.Errorf("error running analyzers: %v", err)
	}
	if diagnostics != "" {
		return fmt.Errorf("errors found by nogo during build-time code analysis:\n%s\n", diagnostics)
	}
	if *xPath != "" {
		if err := os.WriteFile(abs(*xPath), facts, 0o666); err != nil {
			return fmt.Errorf("error writing facts: %v", err)
		}
	}

	return nil
}

// Adapted from go/src/cmd/compile/internal/gc/main.go. Keep in sync.
func readImportCfg(file string) (packageFile map[string]string, importMap map[string]string, err error) {
	packageFile, importMap = make(map[string]string), make(map[string]string)
	data, err := os.ReadFile(file)
	if err != nil {
		return nil, nil, fmt.Errorf("-importcfg: %v", err)
	}

	for lineNum, line := range strings.Split(string(data), "\n") {
		lineNum++ // 1-based
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		var verb, args string
		if i := strings.Index(line, " "); i < 0 {
			verb = line
		} else {
			verb, args = line[:i], strings.TrimSpace(line[i+1:])
		}
		var before, after string
		if i := strings.Index(args, "="); i >= 0 {
			before, after = args[:i], args[i+1:]
		}
		switch verb {
		default:
			return nil, nil, fmt.Errorf("%s:%d: unknown directive %q", file, lineNum, verb)
		case "importmap":
			if before == "" || after == "" {
				return nil, nil, fmt.Errorf(`%s:%d: invalid importmap: syntax is "importmap old=new"`, file, lineNum)
			}
			importMap[before] = after
		case "packagefile":
			if before == "" || after == "" {
				return nil, nil, fmt.Errorf(`%s:%d: invalid packagefile: syntax is "packagefile path=filename"`, file, lineNum)
			}
			packageFile[before] = after
		}
	}
	return packageFile, importMap, nil
}

// checkPackage runs all the given analyzers on the specified package and
// returns the source code diagnostics that the must be printed in the build log.
// It returns an empty string if no source code diagnostics need to be printed.
//
// This implementation was adapted from that of golang.org/x/tools/go/checker/internal/checker.
func checkPackage(analyzers []*analysis.Analyzer, packagePath string, packageFile, importMap map[string]string, factMap map[string]string, filenames []string) (string, []byte, error) {
	// Register fact types and establish dependencies between analyzers.
	actions := make(map[*analysis.Analyzer]*action)
	var visit func(a *analysis.Analyzer) *action
	visit = func(a *analysis.Analyzer) *action {
		act, ok := actions[a]
		if !ok {
			act = &action{a: a}
			actions[a] = act
			for _, f := range a.FactTypes {
				act.usesFacts = true
				gob.Register(f)
			}
			act.deps = make([]*action, len(a.Requires))
			for i, req := range a.Requires {
				dep := visit(req)
				if dep.usesFacts {
					act.usesFacts = true
				}
				act.deps[i] = dep
			}
		}
		return act
	}

	roots := make([]*action, 0, len(analyzers))
	for _, a := range analyzers {
		if cfg, ok := configs[a.Name]; ok {
			for flagKey, flagVal := range cfg.analyzerFlags {
				if strings.HasPrefix(flagKey, "-") {
					return "", nil, fmt.Errorf(
						"%s: flag should not begin with '-': %s", a.Name, flagKey)
				}
				if flag := a.Flags.Lookup(flagKey); flag == nil {
					return "", nil, fmt.Errorf("%s: unrecognized flag: %s", a.Name, flagKey)
				}
				if err := a.Flags.Set(flagKey, flagVal); err != nil {
					return "", nil, fmt.Errorf(
						"%s: invalid value for flag: %s=%s: %w", a.Name, flagKey, flagVal, err)
				}
			}
		}
		roots = append(roots, visit(a))
	}

	// Load the package, including AST, types, and facts.
	imp := newImporter(importMap, packageFile, factMap)
	pkg, err := load(packagePath, imp, filenames)
	if err != nil {
		return "", nil, fmt.Errorf("error loading package: %v", err)
	}
	for _, act := range actions {
		act.pkg = pkg
	}

	// Process nolint directives similar to golangci-lint.
	for _, f := range pkg.syntax {
		// CommentMap will correctly associate comments to the largest node group
		// applicable. This handles inline comments that might trail a large
		// assignment and will apply the comment to the entire assignment.
		commentMap := ast.NewCommentMap(pkg.fset, f, f.Comments)
		for node, groups := range commentMap {
			rng := &Range{
				from: pkg.fset.Position(node.Pos()),
				to:   pkg.fset.Position(node.End()).Line,
			}
			for _, group := range groups {
				for _, comm := range group.List {
					linters, ok := parseNolint(comm.Text)
					if !ok {
						continue
					}
					for analyzer, act := range actions {
						if linters == nil || linters[analyzer.Name] {
							act.nolint = append(act.nolint, rng)
						}
					}
				}
			}
		}
	}

	// Execute the analyzers.
	execAll(roots)

	// Process diagnostics and encode facts for importers of this package.
	diagnostics := checkAnalysisResults(roots, pkg)
	facts := pkg.facts.Encode()
	return diagnostics, facts, nil
}

type Range struct {
	from token.Position
	to   int
}

// An action represents one unit of analysis work: the application of
// one analysis to one package. Actions form a DAG within a
// package (as different analyzers are applied, either in sequence or
// parallel).
type action struct {
	once        sync.Once
	a           *analysis.Analyzer
	pass        *analysis.Pass
	pkg         *goPackage
	deps        []*action
	inputs      map[*analysis.Analyzer]interface{}
	result      interface{}
	diagnostics []analysis.Diagnostic
	usesFacts   bool
	err         error
	nolint      []*Range
}

func (act *action) String() string {
	return fmt.Sprintf("%s@%s", act.a, act.pkg)
}

func execAll(actions []*action) {
	var wg sync.WaitGroup
	wg.Add(len(actions))
	for _, act := range actions {
		go func(act *action) {
			defer wg.Done()
			act.exec()
		}(act)
	}
	wg.Wait()
}

func (act *action) exec() { act.once.Do(act.execOnce) }

func (act *action) execOnce() {
	// Analyze dependencies.
	execAll(act.deps)

	// Report an error if any dependency failed.
	var failed []string
	for _, dep := range act.deps {
		if dep.err != nil {
			failed = append(failed, dep.String())
		}
	}
	if failed != nil {
		sort.Strings(failed)
		act.err = fmt.Errorf("failed prerequisites: %s", strings.Join(failed, ", "))
		return
	}

	// Plumb the output values of the dependencies
	// into the inputs of this action.
	inputs := make(map[*analysis.Analyzer]interface{})
	for _, dep := range act.deps {
		// Same package, different analysis (horizontal edge):
		// in-memory outputs of prerequisite analyzers
		// become inputs to this analysis pass.
		inputs[dep.a] = dep.result
	}

	ignoreNolintReporter := func(d analysis.Diagnostic) {
		pos := act.pkg.fset.Position(d.Pos)
		for _, rng := range act.nolint {
			// The list of nolint ranges is built for the entire package. Make sure we
			// only apply ranges to the correct file.
			if pos.Filename != rng.from.Filename {
				continue
			}
			if pos.Line < rng.from.Line || pos.Line > rng.to {
				continue
			}
			// Found a nolint range. Ignore the issue.
			return
		}
		act.diagnostics = append(act.diagnostics, d)
	}

	// Run the analysis.
	factFilter := make(map[reflect.Type]bool)
	for _, f := range act.a.FactTypes {
		factFilter[reflect.TypeOf(f)] = true
	}
	pass := &analysis.Pass{
		Analyzer:          act.a,
		Fset:              act.pkg.fset,
		Files:             act.pkg.syntax,
		Pkg:               act.pkg.types,
		TypesInfo:         act.pkg.typesInfo,
		ResultOf:          inputs,
		Report:            ignoreNolintReporter,
		ImportPackageFact: act.pkg.facts.ImportPackageFact,
		ExportPackageFact: act.pkg.facts.ExportPackageFact,
		ImportObjectFact:  act.pkg.facts.ImportObjectFact,
		ExportObjectFact:  act.pkg.facts.ExportObjectFact,
		AllPackageFacts:   func() []analysis.PackageFact { return act.pkg.facts.AllPackageFacts(factFilter) },
		AllObjectFacts:    func() []analysis.ObjectFact { return act.pkg.facts.AllObjectFacts(factFilter) },
		TypesSizes:        typesSizes,
	}
	act.pass = pass

	var err error
	if act.pkg.illTyped && !pass.Analyzer.RunDespiteErrors {
		err = fmt.Errorf("analysis skipped due to type-checking error: %v", act.pkg.typeCheckError)
	} else {
		act.result, err = pass.Analyzer.Run(pass)
		if err == nil {
			if got, want := reflect.TypeOf(act.result), pass.Analyzer.ResultType; got != want {
				err = fmt.Errorf(
					"internal error: on package %s, analyzer %s returned a result of type %v, but declared ResultType %v",
					pass.Pkg.Path(), pass.Analyzer, got, want)
			}
		}
	}
	act.err = err
}

// load parses and type checks the source code in each file in filenames.
// load also deserializes facts stored for imported packages.
func load(packagePath string, imp *importer, filenames []string) (*goPackage, error) {
	if len(filenames) == 0 {
		return nil, errors.New("no filenames")
	}
	var syntax []*ast.File
	for _, file := range filenames {
		s, err := parser.ParseFile(imp.fset, file, nil, parser.ParseComments)
		if err != nil {
			return nil, err
		}
		syntax = append(syntax, s)
	}
	pkg := &goPackage{fset: imp.fset, syntax: syntax}

	config := types.Config{Importer: imp}
	info := &types.Info{
		Types:      make(map[ast.Expr]types.TypeAndValue),
		Uses:       make(map[*ast.Ident]types.Object),
		Defs:       make(map[*ast.Ident]types.Object),
		Implicits:  make(map[ast.Node]types.Object),
		Scopes:     make(map[ast.Node]*types.Scope),
		Selections: make(map[*ast.SelectorExpr]*types.Selection),
	}

	initInstanceInfo(info)

	types, err := config.Check(packagePath, pkg.fset, syntax, info)
	if err != nil {
		pkg.illTyped, pkg.typeCheckError = true, err
	}
	pkg.types, pkg.typesInfo = types, info

	pkg.facts, err = facts.NewDecoder(pkg.types).Decode(imp.readFacts)
	if err != nil {
		return nil, fmt.Errorf("internal error decoding facts: %v", err)
	}

	return pkg, nil
}

// A goPackage describes a loaded Go package.
type goPackage struct {
	// fset provides position information for types, typesInfo, and syntax.
	// It is set only when types is set.
	fset *token.FileSet
	// syntax is the package's syntax trees.
	syntax []*ast.File
	// types provides type information for the package.
	types *types.Package
	// facts contains information saved by the analysis framework. Passes may
	// import facts for imported packages and may also export facts for this
	// package to be consumed by analyses in downstream packages.
	facts *facts.Set
	// illTyped indicates whether the package or any dependency contains errors.
	// It is set only when types is set.
	illTyped bool
	// typeCheckError contains any error encountered during type-checking. It is
	// only set when illTyped is true.
	typeCheckError error
	// typesInfo provides type information about the package's syntax trees.
	// It is set only when syntax is set.
	typesInfo *types.Info
}

func (g *goPackage) String() string {
	return g.types.Path()
}

// checkAnalysisResults checks the analysis diagnostics in the given actions
// and returns a string containing all the diagnostics that should be printed
// to the build log.
func checkAnalysisResults(actions []*action, pkg *goPackage) string {
	type entry struct {
		analysis.Diagnostic
		*analysis.Analyzer
	}
	var diagnostics []entry
	var errs []error
	for _, act := range actions {
		if act.err != nil {
			// Analyzer failed.
			errs = append(errs, fmt.Errorf("analyzer %q failed: %v", act.a.Name, act.err))
			continue
		}
		if len(act.diagnostics) == 0 {
			continue
		}
		var currentConfig config
		// Use the base config if it exists.
		if baseConfig, ok := configs[nogoBaseConfigName]; ok {
			currentConfig = baseConfig
		}
		// Overwrite the config with the desired config. Any unset fields
		// in the config will default to the base config.
		if actionConfig, ok := configs[act.a.Name]; ok {
			if actionConfig.analyzerFlags != nil {
				currentConfig.analyzerFlags = actionConfig.analyzerFlags
			}
			if actionConfig.onlyFiles != nil {
				currentConfig.onlyFiles = actionConfig.onlyFiles
			}
			if actionConfig.excludeFiles != nil {
				currentConfig.excludeFiles = actionConfig.excludeFiles
			}
		}

		if currentConfig.onlyFiles == nil && currentConfig.excludeFiles == nil {
			for _, diag := range act.diagnostics {
				diagnostics = append(diagnostics, entry{Diagnostic: diag, Analyzer: act.a})
			}
			continue
		}
		// Discard diagnostics based on the analyzer configuration.
		for _, d := range act.diagnostics {
			// NOTE(golang.org/issue/31008): nilness does not set positions,
			// so don't assume the position is valid.
			p := pkg.fset.Position(d.Pos)
			filename := "-"
			if p.IsValid() {
				filename = p.Filename
			}
			include := true
			if len(currentConfig.onlyFiles) > 0 {
				// This analyzer emits diagnostics for only a set of files.
				include = false
				for _, pattern := range currentConfig.onlyFiles {
					if pattern.MatchString(filename) {
						include = true
						break
					}
				}
			}
			if include {
				for _, pattern := range currentConfig.excludeFiles {
					if pattern.MatchString(filename) {
						include = false
						break
					}
				}
			}
			if include {
				diagnostics = append(diagnostics, entry{Diagnostic: d, Analyzer: act.a})
			}
		}
	}
	if len(diagnostics) == 0 && len(errs) == 0 {
		return ""
	}

	sort.Slice(diagnostics, func(i, j int) bool {
		return diagnostics[i].Pos < diagnostics[j].Pos
	})
	errMsg := &bytes.Buffer{}
	sep := ""
	for _, err := range errs {
		errMsg.WriteString(sep)
		sep = "\n"
		errMsg.WriteString(err.Error())
	}
	for _, d := range diagnostics {
		errMsg.WriteString(sep)
		sep = "\n"
		fmt.Fprintf(errMsg, "%s: %s (%s)", pkg.fset.Position(d.Pos), d.Message, d.Name)
	}
	return errMsg.String()
}

// config determines which source files an analyzer will emit diagnostics for.
// config values are generated in another file that is compiled with
// nogo_main.go by the nogo rule.
type config struct {
	// onlyFiles is a list of regular expressions that match files an analyzer
	// will emit diagnostics for. When empty, the analyzer will emit diagnostics
	// for all files.
	onlyFiles []*regexp.Regexp

	// excludeFiles is a list of regular expressions that match files that an
	// analyzer will not emit diagnostics for.
	excludeFiles []*regexp.Regexp

	// analyzerFlags is a map of flag names to flag values which will be passed
	// to Analyzer.Flags. Note that no leading '-' should be present in a flag
	// name
	analyzerFlags map[string]string
}

// importer is an implementation of go/types.Importer that imports type
// information from the export data in compiled .a files.
type importer struct {
	fset         *token.FileSet
	importMap    map[string]string         // map import path in source code to package path
	packageCache map[string]*types.Package // cache of previously imported packages
	packageFile  map[string]string         // map package path to .a file with export data
	factMap      map[string]string         // map import path in source code to file containing serialized facts
}

func newImporter(importMap, packageFile map[string]string, factMap map[string]string) *importer {
	return &importer{
		fset:         token.NewFileSet(),
		importMap:    importMap,
		packageCache: make(map[string]*types.Package),
		packageFile:  packageFile,
		factMap:      factMap,
	}
}

func (i *importer) Import(path string) (*types.Package, error) {
	if imp, ok := i.importMap[path]; ok {
		// Translate import path if necessary.
		path = imp
	}
	if path == "unsafe" {
		// Special case: go/types has pre-defined type information for unsafe.
		// See https://github.com/golang/go/issues/13882.
		return types.Unsafe, nil
	}
	if pkg, ok := i.packageCache[path]; ok && pkg.Complete() {
		return pkg, nil // cache hit
	}

	archive, ok := i.packageFile[path]
	if !ok {
		return nil, fmt.Errorf("could not import %q", path)
	}
	// open file
	f, err := os.Open(archive)
	if err != nil {
		return nil, err
	}
	defer func() {
		f.Close()
		if err != nil {
			// add file name to error
			err = fmt.Errorf("reading export data: %s: %v", archive, err)
		}
	}()

	r, err := gcexportdata.NewReader(f)
	if err != nil {
		return nil, err
	}

	return gcexportdata.Read(r, i.fset, i.packageCache, path)
}

func (i *importer) readFacts(pkg *types.Package) ([]byte, error) {
	archive := i.factMap[pkg.Path()]
	if archive == "" {
		// Packages that were not built with the nogo toolchain will not be
		// analyzed, so there's no opportunity to store facts. This includes
		// packages in the standard library and packages built with go_tool_library,
		// such as coverdata. Analyzers are expected to hard code information
		// about standard library definitions and must gracefully handle packages
		// that don't have facts. For example, the "printf" analyzer must know
		// fmt.Printf accepts a format string.
		return nil, nil
	}
	factReader, err := readFileInArchive(nogoFact, archive)
	if os.IsNotExist(err) {
		// Packages that were not built with the nogo toolchain will not be
		// analyzed, so there's no opportunity to store facts. This includes
		// packages in the standard library and packages built with go_tool_library,
		// such as coverdata.
		return nil, nil
	} else if err != nil {
		return nil, err
	}
	defer factReader.Close()
	return io.ReadAll(factReader)
}

type factMultiFlag map[string]string

func (m *factMultiFlag) String() string {
	if m == nil || len(*m) == 0 {
		return ""
	}
	return fmt.Sprintf("%v", *m)
}

func (m *factMultiFlag) Set(v string) error {
	parts := strings.Split(v, "=")
	if len(parts) != 2 {
		return fmt.Errorf("badly formatted -fact flag: %s", v)
	}
	(*m)[parts[0]] = parts[1]
	return nil
}
