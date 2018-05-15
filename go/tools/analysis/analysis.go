// Copyright 2018 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// The analysis package defines a uniform interface for static checkers
// of Go source code. By implementing a common interface, checkers from
// a variety of sources can be easily selected, incorporated, and reused
// in a wide range of programs including command-line tools, text
// editors and IDEs, build systems, test frameworks, code review tools,
// and batch pipelines for large code bases.
//
// Each analysis is invoked once per Go package, and is provided the
// abstract syntax trees (ASTs) and type information for that package.
//
// The package also contains a global registry of analyses.
// Call Register to add an analysis to the set.
package analysis

import (
	"errors"
	"flag"
	"go/ast"
	"go/token"
	"go/types"
	"log"
	"sort"
	"sync"
)

// An Analysis describes an analysis function and its options.
type Analysis struct {
	Name string

	// Flags defines any flags accepted by the analysis.
	// The manner in which these flags are exposed to the user
	// depends on the framework which uses the analysis.
	Flags flag.FlagSet

	// Run applies the analysis to a Package.
	//
	// It returns an error if the analysis failed.
	// The ErrSkipped error indicates that it was not appropriate to
	// run the analysis, for instance because it requires but did
	// not get an error-free input.
	Run func(*Package) (*Result, error)
}

// ErrSkipped indicates that an analysis was skipped.
var ErrSkipped = errors.New("skipping package")

// A Package describes a package of Go source code to be analyzed.
type Package struct {
	// syntax trees
	Fset        *token.FileSet // file position information
	Files       []*ast.File    // the abstract syntax tree of each file
	ParseErrors bool           // whether there were errors during parsing

	// type information
	Types      *types.Package // type information about the package
	Info       *types.Info    // type information about the syntax trees
	TypeErrors bool           // whether there were "hard" errors during checking

	// Optional extensions, keyed by unique values.
	//
	// This allows frameworks to provide analyses with additional
	// information about a package, such as its build metadata, SSA
	// representation, or control-flow graph, without establishing
	// unwanted dependencies on all such kinds of information.
	extensionsMu sync.Mutex
	extensions   map[interface{}]interface{}
}

// Extension returns optional extension information about a package,
// such as its SSA representation, or the control-flow graph of a
// particular function.
//
// Extensions are computed lazily on first request (by calling the
// create function) and saved in the package to satisfy subsequent
// requests efficiently. This method is concurrency-safe.
// Some extensions may be eagerly populated by the framework.
//
// Analyses are not expected to call this function directly. Each
// extension should define its own strongly typed wrapper around this
// function, and analyses should call that instead.
//
// The key should uniquely identify both the kind of extension
// and the subcomponent of the package to which it applies, if any.
// For the kind, callers should use a private type to avoid namespace collisions.
// For a fine-grained extension that describes, for example, a single
// function, the key should incorporate the identity of that function.
//
// Not all extensions are provided in all frameworks.
// Analyses should gracefully handle the absence of a given extension.
func (p *Package) Extension(key interface{}, create func(*Package) interface{}) interface{} {
	p.extensionsMu.Lock()
	defer p.extensionsMu.Unlock()

	ext, ok := p.extensions[key]
	if !ok {
		ext = create(p)
		if p.extensions == nil {
			p.extensions = make(map[interface{}]interface{})
		}
		p.extensions[key] = ext
	}
	return ext
}

// A Result describes the results of applying an analysis to a package.
type Result struct {
	Findings []*Finding

	// TODO(adonovan):
	// - diffs (refactorings or cleanups)?
	//   Look at https://github.com/google/error-prone/blob/master/check_api/src/main/java/com/google/errorprone/fixes/Fix.java
	//   for inspiration.
	// - analysis warnings?
}

// A Finding is a message associated with a source location.
type Finding struct {
	Pos, End token.Pos // !End.IsValid() => a point, not a region
	Message  string

	// TODO(adonovan):
	// DocURL   string // optional page documenting this category of finding
}

// Register registers an analysis so that the result of
// subsequent calls to Analyses will include it.
// It is an error to register the same name twice.
func Register(a *Analysis) {
	if a.Name == "" {
		// TODO(adonovan): check that name is a valid identifier,
		// as we'll want to use it in command-line flags, etc.
		log.Fatalf("invalid name: %q", a.Name)
	}
	a.Flags.Init(a.Name, flag.ContinueOnError)
	// TODO(adonovan): set a.Flags.Usage to something useful.

	mu.Lock()
	defer mu.Unlock()
	if analyses[a.Name] != nil {
		log.Fatalf("duplicate analysis %q", a.Name)
	}
	analyses[a.Name] = a
}

// Analyses returns a new slice containing all registered analyses ordered by name.
func Analyses() []*Analysis {
	mu.Lock()
	res := make([]*Analysis, 0, len(analyses))
	for _, a := range analyses {
		res = append(res, a)
	}
	mu.Unlock()

	sort.Slice(res, func(i, j int) bool {
		return res[i].Name < res[j].Name
	})
	return res
}

// registry
var (
	mu       sync.Mutex
	analyses = make(map[string]*Analysis)
)
