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
	"log"
	"os"
	"path/filepath"
	"strings"
)

type archive struct {
	label, importPath, packagePath, aFile, xFile string
}

func buildImportcfgFileForCompile(archives []archive, stdImports []string, installSuffix, dir string) (string, error) {
	buf := &bytes.Buffer{}
	goroot, ok := os.LookupEnv("GOROOT")
	if !ok {
		return "", errors.New("GOROOT not set")
	}
	goroot = abs(goroot)
	// UGLY HACK: The vet tool called by compile program expects the vet.cfg file
	// passed to it to contain import information for package fmt. Since we use
	// importcfg to create vet.cfg, ensure that an entry for package fmt exists in
	// the former.
	stdImports = append(stdImports, "fmt")
	for _, imp := range stdImports {
		path := filepath.Join(goroot, "pkg", installSuffix, filepath.FromSlash(imp))
		fmt.Fprintf(buf, "packagefile %s=%s.a\n", imp, path)
	}
	for _, arc := range archives {
		if arc.importPath != arc.packagePath {
			fmt.Fprintf(buf, "importmap %s=%s\n", arc.importPath, arc.packagePath)
		}
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

func buildImportcfgFileForLink(archives []archive, packageList, installSuffix, dir string) (string, error) {
	buf := &bytes.Buffer{}
	goroot, ok := os.LookupEnv("GOROOT")
	if !ok {
		return "", errors.New("GOROOT not set")
	}
	prefix := abs(filepath.Join(goroot, "pkg", installSuffix))
	packageListFile, err := os.Open(packageList)
	if err != nil {
		return "", err
	}
	defer packageListFile.Close()
	scanner := bufio.NewScanner(packageListFile)
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
		if conflictLabel, ok := depsSeen[arc.packagePath]; ok {
			// TODO(#1327): link.bzl should report this as a failure after 0.11.0.
			// At this point, we'll prepare an importcfg file and remove logic here.
			log.Printf(`warning: package %q is provided by more than one rule:
    %s
    %s
Set "importmap" to different paths in each library.
This will be an error in the future.`, arc.packagePath, arc.label, conflictLabel)
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
	if len(parts) != 4 {
		return fmt.Errorf("badly formed -arc flag: %s", v)
	}
	a := archive{
		importPath:  parts[0],
		packagePath: parts[1],
		aFile:       abs(parts[2]),
	}
	if parts[3] != "" {
		a.xFile = abs(parts[3])
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
