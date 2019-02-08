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

// cgo2.go provides new cgo functionality for use by the GoCompilePkg action.
// We can't use the functionality in cgo.go, since it relies too heavily
// on logic in cgo.bzl. Ideally, we'd be able to replace cgo.go with this
// file eventually, but not until Bazel gives us enough toolchain information
// to compile ObjC files.

package main

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// cgo2 processes a set of mixed source files with cgo.
func cgo2(goenv *env, goSrcs, cgoSrcs, cSrcs, cxxSrcs, sSrcs, hSrcs []string, packagePath, packageName string, cc string, cppFlags, cFlags, cxxFlags, ldFlags []string, cgoExportHPath string) (srcDir string, allGoSrcs, cObjs []string, err error) {
	// Report an error if the C/C++ toolchain wasn't configured.
	if cc == "" {
		err := cgoError(cgoSrcs[:])
		err = append(err, cSrcs...)
		err = append(err, cxxSrcs...)
		err = append(err, sSrcs...)
		return "", nil, nil, err
	}

	// If we only have C/C++ sources without cgo, just compile and pack them
	// without generating code. The Go command forbids this, but we've
	// historically allowed it.
	// TODO(jayconrod): this doesn't write CGO_LDFLAGS into the archive. We
	// might miss dependencies like -lstdc++ if they aren't referenced in
	// some other way.
	if len(cgoSrcs) == 0 {
		cObjs, err = compileCSources(goenv, cSrcs, cxxSrcs, sSrcs, hSrcs, cc, cppFlags, cFlags, cxxFlags)
		return ".", nil, cObjs, err
	}

	workDir, cleanup, err := goenv.workDir()
	if err != nil {
		return "", nil, nil, err
	}
	defer cleanup()

	// Filter out -lstdc++ and -lc++ from ldflags if we don't have C++ sources,
	// and set CGO_LDFLAGS. These flags get written as special comments into cgo
	// generated sources. The compiler encodes those flags in the compiled .a
	// file, and the linker passes them on to the external linker.
	haveCxx := len(cxxSrcs) > 0
	if !haveCxx {
		for _, f := range ldFlags {
			if strings.HasSuffix(f, ".a") {
				// These flags come from cdeps options. Assume C++.
				haveCxx = true
				break
			}
		}
	}
	var combinedLdFlags []string
	if haveCxx {
		combinedLdFlags = append(combinedLdFlags, ldFlags...)
	} else {
		for _, f := range ldFlags {
			if f != "-lc++" && f != "-lstdc++" {
				combinedLdFlags = append(combinedLdFlags, f)
			}
		}
	}
	combinedLdFlags = append(combinedLdFlags, defaultLdFlags()...)
	os.Setenv("CGO_LDFLAGS", strings.Join(combinedLdFlags, " "))

	// If cgo sources are in different directories, gather them into a temporary
	// directory so we can use -srcdir.
	srcDir = filepath.Dir(cgoSrcs[0])
	srcsInSingleDir := true
	for _, src := range cgoSrcs[1:] {
		if filepath.Dir(src) != srcDir {
			srcsInSingleDir = false
			break
		}
	}

	if srcsInSingleDir {
		for i := range cgoSrcs {
			cgoSrcs[i] = filepath.Base(cgoSrcs[i])
		}
	} else {
		srcDir = filepath.Join(workDir, "cgosrcs")
		if err := os.Mkdir(srcDir, 0777); err != nil {
			return "", nil, nil, err
		}
		copiedSrcs, err := gatherSrcs(srcDir, cgoSrcs)
		if err != nil {
			return "", nil, nil, err
		}
		cgoSrcs = copiedSrcs
	}

	// Generate Go and C code.
	hdrDirs := map[string]bool{}
	var hdrIncludes []string
	for _, hdr := range hSrcs {
		hdrDir := filepath.Dir(hdr)
		if !hdrDirs[hdrDir] {
			hdrDirs[hdrDir] = true
			hdrIncludes = append(hdrIncludes, "-iquote", hdrDir)
		}
	}
	hdrIncludes = append(hdrIncludes, "-iquote", workDir) // for _cgo_export.h

	args := goenv.goTool("cgo", "-srcdir", srcDir, "-objdir", workDir)
	if packagePath != "" {
		args = append(args, "-importpath", packagePath)
	}
	args = append(args, "--")
	args = append(args, cppFlags...)
	args = append(args, hdrIncludes...)
	args = append(args, cFlags...)
	args = append(args, cgoSrcs...)
	if err := goenv.runCommand(args); err != nil {
		return "", nil, nil, err
	}

	if cgoExportHPath != "" {
		if err := copyFile(filepath.Join(workDir, "_cgo_export.h"), cgoExportHPath); err != nil {
			return "", nil, nil, err
		}
	}
	genGoSrcs := make([]string, 1+len(cgoSrcs))
	genGoSrcs[0] = filepath.Join(workDir, "_cgo_gotypes.go")
	genCSrcs := make([]string, 1+len(cgoSrcs))
	genCSrcs[0] = filepath.Join(workDir, "_cgo_export.c")
	for i, src := range cgoSrcs {
		stem := strings.TrimSuffix(filepath.Base(src), ".go")
		genGoSrcs[i+1] = filepath.Join(workDir, stem+".cgo1.go")
		genCSrcs[i+1] = filepath.Join(workDir, stem+".cgo2.c")
	}
	cgoMainC := filepath.Join(workDir, "_cgo_main.c")

	// Compile C, C++, and assembly code.
	defaultCFlags := defaultCFlags()
	defaultCFlags = append(defaultCFlags, "-fdebug-prefix-map="+abs(".")+"=.")
	defaultCFlags = append(defaultCFlags, "-fdebug-prefix-map="+workDir+"=.")
	combinedCFlags := append([]string{}, cppFlags...)
	combinedCFlags = append(combinedCFlags, hdrIncludes...)
	combinedCFlags = append(combinedCFlags, cFlags...)
	combinedCFlags = append(combinedCFlags, defaultCFlags...)
	combinedCxxFlags := append([]string{}, cppFlags...)
	combinedCxxFlags = append(combinedCxxFlags, hdrIncludes...)
	combinedCxxFlags = append(combinedCxxFlags, cxxFlags...)
	combinedCxxFlags = append(combinedCxxFlags, defaultCFlags...)

	compileSrcs := append([]string{}, genCSrcs...)
	compileSrcs = append(compileSrcs, cSrcs...)
	compileSrcs = append(compileSrcs, sSrcs...)
	cxxBegin := len(compileSrcs)
	compileSrcs = append(compileSrcs, cxxSrcs...)

	cObjs = make([]string, len(compileSrcs))
	for i := 0; i < len(cObjs); i++ {
		cObjs[i] = filepath.Join(workDir, fmt.Sprintf("_x%d.o", i))
	}

	for i, src := range compileSrcs {
		if i < cxxBegin {
			err = cCompile(goenv, src, cc, combinedCFlags, cObjs[i])
		} else {
			err = cxxCompile(goenv, src, cc, combinedCxxFlags, cObjs[i])
		}
		if err != nil {
			return "", nil, nil, err
		}
	}

	mainObj := filepath.Join(workDir, "_cgo_main.o")
	if err := cCompile(goenv, cgoMainC, cc, combinedCFlags, mainObj); err != nil {
		return "", nil, nil, err
	}

	// Link cgo binary and use the symbols to generate _cgo_import.go.
	mainBin := filepath.Join(workDir, "_cgo_.o") // .o is a lie; it's an executable
	args = append([]string{cc, "-o", mainBin, mainObj}, cObjs...)
	args = append(args, combinedLdFlags...)
	if err := goenv.runCommand(args); err != nil {
		return "", nil, nil, err
	}

	cgoImportsGo := filepath.Join(workDir, "_cgo_imports.go")
	args = goenv.goTool("cgo", "-dynpackage", packageName, "-dynimport", mainBin, "-dynout", cgoImportsGo)
	if err := goenv.runCommand(args); err != nil {
		return "", nil, nil, err
	}
	genGoSrcs = append(genGoSrcs, cgoImportsGo)

	// Copy regular Go source files into the work directory so that we can
	// use -trimpath=workDir.
	goBases, err := gatherSrcs(workDir, goSrcs)
	if err != nil {
		return "", nil, nil, err
	}

	allGoSrcs = make([]string, len(goSrcs)+len(genGoSrcs))
	for i := range goSrcs {
		allGoSrcs[i] = filepath.Join(workDir, goBases[i])
	}
	copy(allGoSrcs[len(goSrcs):], genGoSrcs)
	return workDir, allGoSrcs, cObjs, nil
}

// compileCSources compiles a list of C, C++, and assembly sources into .o
// files to be packed into the archive. It does not run cgo. This is used for
// packages with "cgo = True" but without any .go files that import "C".
// The Go command forbids this, but we have historically allowed it.
func compileCSources(goenv *env, cSrcs, cxxSrcs, sSrcs, hSrcs []string, cc string, cppFlags, cFlags, cxxFlags []string) (cObjs []string, err error) {
	workDir, cleanup, err := goenv.workDir()
	if err != nil {
		return nil, err
	}
	defer cleanup()

	hdrDirs := map[string]bool{}
	var hdrIncludes []string
	for _, hdr := range hSrcs {
		hdrDir := filepath.Dir(hdr)
		if !hdrDirs[hdrDir] {
			hdrDirs[hdrDir] = true
			hdrIncludes = append(hdrIncludes, "-iquote", hdrDir)
		}
	}

	defaultCFlags := defaultCFlags()
	combinedCFlags := append([]string{}, cppFlags...)
	combinedCFlags = append(combinedCFlags, hdrIncludes...)
	combinedCFlags = append(combinedCFlags, cFlags...)
	combinedCFlags = append(combinedCFlags, defaultCFlags...)
	combinedCxxFlags := append([]string{}, cxxFlags...)
	combinedCxxFlags = append(combinedCxxFlags, hdrIncludes...)
	combinedCxxFlags = append(combinedCxxFlags, cxxFlags...)
	combinedCxxFlags = append(combinedCxxFlags, defaultCFlags...)

	compileSrcs := append([]string{}, cSrcs...)
	compileSrcs = append(compileSrcs, sSrcs...)
	cxxBegin := len(compileSrcs)
	compileSrcs = append(compileSrcs, cxxSrcs...)

	cObjs = make([]string, len(compileSrcs))
	for i := 0; i < len(cObjs); i++ {
		cObjs[i] = filepath.Join(workDir, fmt.Sprintf("_x%d.o", i))
	}

	for i, src := range compileSrcs {
		if i < cxxBegin {
			err = cCompile(goenv, src, cc, combinedCFlags, cObjs[i])
		} else {
			err = cxxCompile(goenv, src, cc, combinedCxxFlags, cObjs[i])
		}
		if err != nil {
			return nil, err
		}
	}

	return cObjs, nil
}

func cCompile(goenv *env, src, cc string, cFlags []string, out string) error {
	args := []string{cc, "-c", src, "-o", out}
	args = append(args, cFlags...)
	return goenv.runCommand(args)
}

func cxxCompile(goenv *env, src, cc string, cxxFlags []string, out string) error {
	args := []string{cc, "-x", "c++", "-c", src, "-o", out}
	args = append(args, cxxFlags...)
	return goenv.runCommand(args)
}

func defaultCFlags() []string {
	goos, goarch := os.Getenv("GOOS"), os.Getenv("GOARCH")
	switch {
	case goos == "darwin":
		return nil
	case goos == "windows" && goarch == "amd64":
		return []string{"-mthreads"}
	default:
		return []string{"-pthread"}
	}
}

func defaultLdFlags() []string {
	goos, goarch := os.Getenv("GOOS"), os.Getenv("GOARCH")
	switch {
	case goos == "android":
		return []string{"-llog", "-ldl"}
	case goos == "darwin":
		return nil
	case goos == "windows" && goarch == "amd64":
		return []string{"-mthreads"}
	default:
		return []string{"-pthread"}
	}
}

// gatherSrcs copies or links files listed in srcs into dir. This is needed
// to effectively use -trimpath with generated sources. It's also needed by cgo.
//
// gatherSrcs returns the basenames of copied files in the directory.
func gatherSrcs(dir string, srcs []string) ([]string, error) {
	copiedBases := make([]string, len(srcs))
	for i, src := range srcs {
		base := filepath.Base(src)
		ext := filepath.Ext(base)
		stem := base[:len(base)-len(ext)]
		var err error
		for j := 1; j < 10000; j++ {
			if err = copyOrLinkFile(src, filepath.Join(dir, base)); err == nil {
				break
			} else if !os.IsExist(err) {
				return nil, err
			} else {
				base = fmt.Sprintf("%s_%d%s", stem, j, ext)
			}
		}
		if err != nil {
			return nil, fmt.Errorf("could not find unique name for file %s", src)
		}
		copiedBases[i] = base
	}
	return copiedBases, nil
}

type cgoError []string

func (e cgoError) Error() string {
	b := &bytes.Buffer{}
	fmt.Fprint(b, "CC is not set and files need to be processed with cgo:\n")
	for _, f := range e {
		fmt.Fprintf(b, "\t%s\n", f)
	}
	fmt.Fprintf(b, "Ensure that 'cgo = True' is set and the C/C++ toolchain is configured.")
	return b.String()
}
