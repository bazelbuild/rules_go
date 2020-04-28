// Copyright 2019 The Bazel Authors. All rights reserved.
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

package main

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type archive struct {
	//TODO merge aFile and xFile because compile only needs xFile and link only needs aFile
	label, importPath, packagePath, aFile, xFile string
	importPathAliases                            []string
}

// checkImports verifies that each import in files refers to a
// direct dependendency in archives or to a standard library package
// listed in the file at stdPackageListPath. checkImports returns
// a map from source import paths to elements of archives or to nil
// for standard library packages.
func checkImports(files []fileInfo, archives []archive, stdPackageListPath string) (map[string]*archive, error) {
	// Read the standard package list.
	packagesTxt, err := ioutil.ReadFile(stdPackageListPath)
	if err != nil {
		return nil, err
	}
	stdPkgs := make(map[string]bool)
	for len(packagesTxt) > 0 {
		n := bytes.IndexByte(packagesTxt, '\n')
		var line string
		if n < 0 {
			line = string(packagesTxt)
			packagesTxt = nil
		} else {
			line = string(packagesTxt[:n])
			packagesTxt = packagesTxt[n+1:]
		}
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		stdPkgs[line] = true
	}

	// Index the archives.
	importToArchive := make(map[string]*archive)
	importAliasToArchive := make(map[string]*archive)
	for i := range archives {
		arc := &archives[i]
		importToArchive[arc.importPath] = arc
		for _, imp := range arc.importPathAliases {
			importAliasToArchive[imp] = arc
		}
	}

	// Build the import map.
	imports := make(map[string]*archive)
	var derr depsError
	for _, f := range files {
		for _, path := range f.imports {
			if _, ok := imports[path]; ok || path == "C" || isRelative(path) {
				// TODO(#1645): Support local (relative) import paths. We don't emit
				// errors for them here, but they will probably break something else.
				continue
			}
			if stdPkgs[path] {
				imports[path] = nil
			} else if arc := importToArchive[path]; arc != nil {
				imports[path] = arc
			} else if arc := importAliasToArchive[path]; arc != nil {
				imports[path] = arc
			} else {
				derr.missing = append(derr.missing, missingDep{f.filename, path})
			}
		}
	}
	if len(derr.missing) > 0 {
		return nil, derr
	}
	return imports, nil
}

// buildImportcfgFileForCompile writes an importcfg file to be consumed by the
// compiler. The file is constructed from direct dependencies and std imports.
// The caller is responsible for deleting the importcfg file.
func buildImportcfgFileForCompile(imports map[string]*archive, installSuffix, dir string) (string, error) {
	buf := &bytes.Buffer{}
	goroot, ok := os.LookupEnv("GOROOT")
	if !ok {
		return "", errors.New("GOROOT not set")
	}
	goroot = abs(goroot)

	sortedImports := make([]string, 0, len(imports))
	for imp := range imports {
		sortedImports = append(sortedImports, imp)
	}
	sort.Strings(sortedImports)

	for _, imp := range sortedImports {
		if arc := imports[imp]; arc == nil {
			// std package
			path := filepath.Join(goroot, "pkg", installSuffix, filepath.FromSlash(imp))
			fmt.Fprintf(buf, "packagefile %s=%s.a\n", imp, path)
		} else {
			if imp != arc.packagePath {
				fmt.Fprintf(buf, "importmap %s=%s\n", imp, arc.packagePath)
			}
			fmt.Fprintf(buf, "packagefile %s=%s\n", arc.packagePath, arc.xFile)
		}
	}

	f, err := ioutil.TempFile(dir, "importcfg")
	if err != nil {
		return "", err
	}
	filename := f.Name()
	if _, err := io.Copy(f, buf); err != nil {
		f.Close()
		os.Remove(filename)
		return "", err
	}
	if err := f.Close(); err != nil {
		os.Remove(filename)
		return "", err
	}
	return filename, nil
}

func buildImportcfgFileForLink(archives []archive, stdPackageListPath, installSuffix, dir string) (string, error) {
	buf := &bytes.Buffer{}
	goroot, ok := os.LookupEnv("GOROOT")
	if !ok {
		return "", errors.New("GOROOT not set")
	}
	prefix := abs(filepath.Join(goroot, "pkg", installSuffix))
	stdPackageListFile, err := os.Open(stdPackageListPath)
	if err != nil {
		return "", err
	}
	defer stdPackageListFile.Close()
	scanner := bufio.NewScanner(stdPackageListFile)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		fmt.Fprintf(buf, "packagefile %s=%s.a\n", line, filepath.Join(prefix, filepath.FromSlash(line)))
	}
	if err := scanner.Err(); err != nil {
		return "", err
	}
	depsSeen := map[string]string{}
	for _, arc := range archives {
		if _, ok := depsSeen[arc.packagePath]; ok {
			// If this is detected during analysis, the -conflict_err flag will be set.
			// We'll report that error if -package_conflict_is_error is set or if
			// the link command fails.
			// TODO(#1374): This should always be an error. Panic.
			continue
		}
		depsSeen[arc.packagePath] = arc.label
		fmt.Fprintf(buf, "packagefile %s=%s\n", arc.packagePath, arc.aFile)
	}
	f, err := ioutil.TempFile(dir, "importcfg")
	if err != nil {
		return "", err
	}
	filename := f.Name()
	if _, err := io.Copy(f, buf); err != nil {
		f.Close()
		os.Remove(filename)
		return "", err
	}
	if err := f.Close(); err != nil {
		os.Remove(filename)
		return "", err
	}
	return filename, nil
}

type depsError struct {
	missing []missingDep
	known   []string
}

type missingDep struct {
	filename, imp string
}

var _ error = depsError{}

func (e depsError) Error() string {
	buf := bytes.NewBuffer(nil)
	fmt.Fprintf(buf, "missing strict dependencies:\n")
	for _, dep := range e.missing {
		fmt.Fprintf(buf, "\t%s: import of %q\n", dep.filename, dep.imp)
	}
	if len(e.known) == 0 {
		fmt.Fprintln(buf, "No dependencies were provided.")
	} else {
		fmt.Fprintln(buf, "Known dependencies are:")
		for _, imp := range e.known {
			fmt.Fprintf(buf, "\t%s\n", imp)
		}
	}
	fmt.Fprint(buf, "Check that imports in Go sources match importpath attributes in deps.")
	return buf.String()
}

func isRelative(path string) bool {
	return strings.HasPrefix(path, "./") || strings.HasPrefix(path, "../")
}

// TODO(jayconrod): consolidate compile and link archive flags.

type compileArchiveMultiFlag []archive

func (m *compileArchiveMultiFlag) String() string {
	if m == nil || len(*m) == 0 {
		return ""
	}
	return fmt.Sprint(*m)
}

func (m *compileArchiveMultiFlag) Set(v string) error {
	parts := strings.Split(v, "=")
	if len(parts) != 3 {
		return fmt.Errorf("badly formed -arc flag: %s", v)
	}
	importPaths := strings.Split(parts[0], ":")
	a := archive{
		importPath:        importPaths[0],
		importPathAliases: importPaths[1:],
		packagePath:       parts[1],
		xFile:             abs(parts[2]),
	}
	*m = append(*m, a)
	return nil
}

type linkArchiveMultiFlag []archive

func (m *linkArchiveMultiFlag) String() string {
	if m == nil || len(*m) == 0 {
		return ""
	}
	return fmt.Sprint(m)
}

func (m *linkArchiveMultiFlag) Set(v string) error {
	parts := strings.Split(v, "=")
	if len(parts) != 3 {
		return fmt.Errorf("badly formed -arc flag: %s", v)
	}
	*m = append(*m, archive{
		label:       parts[0],
		packagePath: parts[1],
		aFile:       abs(parts[2]),
	})
	return nil
}
