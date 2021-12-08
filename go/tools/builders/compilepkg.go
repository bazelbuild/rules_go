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

// compilepkg compiles a complete Go package from Go, C, and assembly files.  It
// supports cgo, coverage, and nogo. It is invoked by the Go rules as an action.
package main

import (
	"bytes"
	"context"
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"sort"
	"strings"
)

func compilePkg(args []string) error {
	// Parse arguments.
	args, err := expandParamsFiles(args)
	if err != nil {
		return err
	}

	fs := flag.NewFlagSet("GoCompilePkg", flag.ExitOnError)
	goenv := envFlags(fs)
	var unfilteredSrcs, coverSrcs, embedSrcs multiFlag
	var deps archiveMultiFlag
	var importPath, packagePath, nogoPath, packageListPath, coverMode string
	var outPath, outFactsPath, cgoExportHPath string
	var testFilter string
	var gcFlags, asmFlags, cppFlags, cFlags, cxxFlags, objcFlags, objcxxFlags, ldFlags quoteMultiFlag
	fs.Var(&unfilteredSrcs, "src", ".go, .c, .cc, .m, .mm, .s, or .S file to be filtered and compiled")
	fs.Var(&coverSrcs, "cover", ".go file that should be instrumented for coverage (must also be a -src)")
	fs.Var(&embedSrcs, "embedsrc", "file that may be compiled into the package with a //go:embed directive")
	fs.Var(&deps, "arc", "Import path, package path, and file name of a direct dependency, separated by '='")
	fs.StringVar(&importPath, "importpath", "", "The import path of the package being compiled. Not passed to the compiler, but may be displayed in debug data.")
	fs.StringVar(&packagePath, "p", "", "The package path (importmap) of the package being compiled")
	fs.Var(&gcFlags, "gcflags", "Go compiler flags")
	fs.Var(&asmFlags, "asmflags", "Go assembler flags")
	fs.Var(&cppFlags, "cppflags", "C preprocessor flags")
	fs.Var(&cFlags, "cflags", "C compiler flags")
	fs.Var(&cxxFlags, "cxxflags", "C++ compiler flags")
	fs.Var(&objcFlags, "objcflags", "Objective-C compiler flags")
	fs.Var(&objcxxFlags, "objcxxflags", "Objective-C++ compiler flags")
	fs.Var(&ldFlags, "ldflags", "C linker flags")
	fs.StringVar(&nogoPath, "nogo", "", "The nogo binary. If unset, nogo will not be run.")
	fs.StringVar(&packageListPath, "package_list", "", "The file containing the list of standard library packages")
	fs.StringVar(&coverMode, "cover_mode", "", "The coverage mode to use. Empty if coverage instrumentation should not be added.")
	fs.StringVar(&outPath, "o", "", "The output archive file to write compiled code")
	fs.StringVar(&outFactsPath, "x", "", "The output archive file to write export data and nogo facts")
	fs.StringVar(&cgoExportHPath, "cgoexport", "", "The _cgo_exports.h file to write")
	fs.StringVar(&testFilter, "testfilter", "off", "Controls test package filtering")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if err := goenv.checkFlags(); err != nil {
		return err
	}
	if importPath == "" {
		importPath = packagePath
	}
	cgoEnabled := os.Getenv("CGO_ENABLED") == "1"
	cc := os.Getenv("CC")
	outPath = abs(outPath)
	for i := range unfilteredSrcs {
		unfilteredSrcs[i] = abs(unfilteredSrcs[i])
	}
	for i := range embedSrcs {
		embedSrcs[i] = abs(embedSrcs[i])
	}
	for i := range coverSrcs {
		coverSrcs[i] = abs(coverSrcs[i])
	}

	// Filter sources.
	srcs, err := filterAndSplitFiles(unfilteredSrcs)
	if err != nil {
		return err
	}

	// TODO(jayconrod): remove -testfilter flag. The test action should compile
	// the main, internal, and external packages by calling compileArchive
	// with the correct sources for each.
	switch testFilter {
	case "off":
	case "only":
		testSrcs := make([]fileInfo, 0, len(srcs.goSrcs))
		for _, f := range srcs.goSrcs {
			if strings.HasSuffix(f.pkg, "_test") {
				testSrcs = append(testSrcs, f)
			}
		}
		srcs.goSrcs = testSrcs
	case "exclude":
		libSrcs := make([]fileInfo, 0, len(srcs.goSrcs))
		for _, f := range srcs.goSrcs {
			if !strings.HasSuffix(f.pkg, "_test") {
				libSrcs = append(libSrcs, f)
			}
		}
		srcs.goSrcs = libSrcs
	default:
		return fmt.Errorf("invalid test filter %q", testFilter)
	}

	return compileArchive(
		goenv,
		importPath,
		packagePath,
		srcs,
		deps,
		coverMode,
		coverSrcs,
		embedSrcs,
		cgoEnabled,
		cc,
		gcFlags,
		asmFlags,
		cppFlags,
		cFlags,
		cxxFlags,
		objcFlags,
		objcxxFlags,
		ldFlags,
		nogoPath,
		packageListPath,
		outPath,
		outFactsPath,
		cgoExportHPath)
}

func compileArchive(
	goenv *env,
	importPath string,
	packagePath string,
	srcs archiveSrcs,
	deps []archive,
	coverMode string,
	coverSrcs []string,
	embedSrcs []string,
	cgoEnabled bool,
	cc string,
	gcFlags []string,
	asmFlags []string,
	cppFlags []string,
	cFlags []string,
	cxxFlags []string,
	objcFlags []string,
	objcxxFlags []string,
	ldFlags []string,
	nogoPath string,
	packageListPath string,
	outPath string,
	outXPath string,
	cgoExportHPath string) error {

	workDir, cleanup, err := goenv.workDir()
	if err != nil {
		return err
	}
	defer cleanup()

	if len(srcs.goSrcs) == 0 {
		emptyPath := filepath.Join(workDir, "_empty.go")
		if err := ioutil.WriteFile(emptyPath, []byte("package empty\n"), 0666); err != nil {
			return err
		}
		srcs.goSrcs = append(srcs.goSrcs, fileInfo{
			filename: emptyPath,
			ext:      goExt,
			matched:  true,
			pkg:      "empty",
		})
		defer os.Remove(emptyPath)
	}
	packageName := srcs.goSrcs[0].pkg
	var goSrcs, cgoSrcs []string
	for _, src := range srcs.goSrcs {
		if src.isCgo {
			cgoSrcs = append(cgoSrcs, src.filename)
		} else {
			goSrcs = append(goSrcs, src.filename)
		}
	}
	cSrcs := make([]string, len(srcs.cSrcs))
	for i, src := range srcs.cSrcs {
		cSrcs[i] = src.filename
	}
	cxxSrcs := make([]string, len(srcs.cxxSrcs))
	for i, src := range srcs.cxxSrcs {
		cxxSrcs[i] = src.filename
	}
	objcSrcs := make([]string, len(srcs.objcSrcs))
	for i, src := range srcs.objcSrcs {
		objcSrcs[i] = src.filename
	}
	objcxxSrcs := make([]string, len(srcs.objcxxSrcs))
	for i, src := range srcs.objcxxSrcs {
		objcxxSrcs[i] = src.filename
	}
	sSrcs := make([]string, len(srcs.sSrcs))
	for i, src := range srcs.sSrcs {
		sSrcs[i] = src.filename
	}
	hSrcs := make([]string, len(srcs.hSrcs))
	for i, src := range srcs.hSrcs {
		hSrcs[i] = src.filename
	}
	haveCgo := len(cgoSrcs)+len(cSrcs)+len(cxxSrcs)+len(objcSrcs)+len(objcxxSrcs) > 0

	// Instrument source files for coverage.
	if coverMode != "" {
		shouldCover := make(map[string]bool)
		for _, s := range coverSrcs {
			shouldCover[s] = true
		}

		combined := append([]string{}, goSrcs...)
		if cgoEnabled {
			combined = append(combined, cgoSrcs...)
		}
		for i, origSrc := range combined {
			if !shouldCover[origSrc] {
				continue
			}

			srcName := origSrc
			if importPath != "" {
				srcName = path.Join(importPath, filepath.Base(origSrc))
			}

			stem := filepath.Base(origSrc)
			if ext := filepath.Ext(stem); ext != "" {
				stem = stem[:len(stem)-len(ext)]
			}
			coverVar := fmt.Sprintf("Cover_%s_%d_%s", sanitizePathForIdentifier(importPath), i, sanitizePathForIdentifier(stem))
			coverVar = strings.ReplaceAll(coverVar, "_", "Z")
			coverSrc := filepath.Join(workDir, fmt.Sprintf("cover_%d.go", i))
			if err := instrumentForCoverage(goenv, origSrc, srcName, coverVar, coverMode, coverSrc); err != nil {
				return err
			}

			if i < len(goSrcs) {
				goSrcs[i] = coverSrc
			} else {
				cgoSrcs[i-len(goSrcs)] = coverSrc
			}
		}
	}

	// If we have cgo, generate separate C and go files, and compile the
	// C files.
	var objFiles []string
	if cgoEnabled && haveCgo {
		// TODO(#2006): Compile .s and .S files with cgo2, not the Go assembler.
		// If cgo is not enabled or we don't have other cgo sources, don't
		// compile .S files.
		var srcDir string
		srcDir, goSrcs, objFiles, err = cgo2(goenv, goSrcs, cgoSrcs, cSrcs, cxxSrcs, objcSrcs, objcxxSrcs, nil, hSrcs, packagePath, packageName, cc, cppFlags, cFlags, cxxFlags, objcFlags, objcxxFlags, ldFlags, cgoExportHPath)
		if err != nil {
			return err
		}

		gcFlags = append(gcFlags, createTrimPath(gcFlags, srcDir))
	} else {
		if cgoExportHPath != "" {
			if err := ioutil.WriteFile(cgoExportHPath, nil, 0666); err != nil {
				return err
			}
		}
		gcFlags = append(gcFlags, createTrimPath(gcFlags, "."))
	}

	// Check that the filtered sources don't import anything outside of
	// the standard library and the direct dependencies.
	imports, err := checkImports(srcs.goSrcs, deps, packageListPath)
	if err != nil {
		return err
	}
	if cgoEnabled && len(cgoSrcs) != 0 {
		// cgo generated code imports some extra packages.
		imports["runtime/cgo"] = nil
		imports["syscall"] = nil
		imports["unsafe"] = nil
	}
	if coverMode != "" {
		if coverMode == "atomic" {
			imports["sync/atomic"] = nil
		}
		const coverdataPath = "github.com/bazelbuild/rules_go/go/tools/coverdata"
		var coverdata *archive
		for i := range deps {
			if deps[i].importPath == coverdataPath {
				coverdata = &deps[i]
				break
			}
		}
		if coverdata == nil {
			return errors.New("coverage requested but coverdata dependency not provided")
		}
		imports[coverdataPath] = coverdata
	}

	// Build an importcfg file for the compiler.
	importcfgPath, err := buildImportcfgFileForCompile(imports, goenv.installSuffix, filepath.Dir(outPath))
	if err != nil {
		return err
	}
	defer os.Remove(importcfgPath)

	// Build an embedcfg file mapping embed patterns to filenames.
	// Embed patterns are relative to any one of a list of root directories
	// that may contain embeddable files. Source files containing embed patterns
	// must be in one of these root directories so the pattern appears to be
	// relative to the source file. Usually, there are two roots: the source
	// directory, and the output directory (so that generated files are
	// embeddable). There may be additional roots if sources are in multiple
	// directories (like if there are are generated source files).
	var srcDirs []string
	srcDirs = append(srcDirs, filepath.Dir(outPath))
	for _, src := range srcs.goSrcs {
		srcDirs = append(srcDirs, filepath.Dir(src.filename))
	}
	sort.Strings(srcDirs) // group duplicates to uniq them below.
	embedRootDirs := srcDirs[:1]
	for _, dir := range srcDirs {
		prev := embedRootDirs[len(embedRootDirs)-1]
		if dir == prev || strings.HasPrefix(dir, prev+string(filepath.Separator)) {
			// Skip duplicates.
			continue
		}
		embedRootDirs = append(embedRootDirs, dir)
	}
	embedcfgPath, err := buildEmbedcfgFile(srcs.goSrcs, embedSrcs, embedRootDirs, workDir)
	if err != nil {
		return err
	}
	if embedcfgPath != "" {
		defer os.Remove(embedcfgPath)
	}

	// Run nogo concurrently.
	var nogoChan chan error
	outFactsPath := filepath.Join(workDir, nogoFact)
	if nogoPath != "" {
		ctx, cancel := context.WithCancel(context.Background())
		nogoChan = make(chan error)
		go func() {
			nogoChan <- runNogo(ctx, workDir, nogoPath, goSrcs, deps, packagePath, importcfgPath, outFactsPath)
		}()
		defer func() {
			if nogoChan != nil {
				cancel()
				<-nogoChan
			}
		}()
	}

	// If there are assembly files, and this is go1.12+, generate symbol ABIs.
	asmHdrPath := ""
	if len(srcs.sSrcs) > 0 {
		asmHdrPath = filepath.Join(workDir, "go_asm.h")
	}
	symabisPath, err := buildSymabisFile(goenv, srcs.sSrcs, srcs.hSrcs, asmHdrPath)
	if symabisPath != "" {
		defer os.Remove(symabisPath)
	}
	if err != nil {
		return err
	}

	// Compile the filtered .go files.
	if err := compileGo(goenv, goSrcs, packagePath, importcfgPath, embedcfgPath, asmHdrPath, symabisPath, gcFlags, outPath); err != nil {
		return err
	}

	// Compile the .s files.
	if len(srcs.sSrcs) > 0 {
		includeSet := map[string]struct{}{
			filepath.Join(os.Getenv("GOROOT"), "pkg", "include"): struct{}{},
			workDir: struct{}{},
		}
		for _, hdr := range srcs.hSrcs {
			includeSet[filepath.Dir(hdr.filename)] = struct{}{}
		}
		includes := make([]string, len(includeSet))
		for inc := range includeSet {
			includes = append(includes, inc)
		}
		sort.Strings(includes)
		for _, inc := range includes {
			asmFlags = append(asmFlags, "-I", inc)
		}
		for i, sSrc := range srcs.sSrcs {
			obj := filepath.Join(workDir, fmt.Sprintf("s%d.o", i))
			if err := asmFile(goenv, sSrc.filename, asmFlags, obj); err != nil {
				return err
			}
			objFiles = append(objFiles, obj)
		}
	}

	// Pack .o files into the archive. These may come from cgo generated code,
	// cgo dependencies (cdeps), or assembly.
	if len(objFiles) > 0 {
		if err := appendFiles(goenv, outPath, objFiles); err != nil {
			return err
		}
	}

	// Check results from nogo.
	nogoStatus := nogoNotRun
	if nogoChan != nil {
		err := <-nogoChan
		nogoChan = nil // no cancellation needed
		if err != nil {
			nogoStatus = nogoFailed
			// TODO: should we still create the .x file without nogo facts in this case?
			return err
		}
		nogoStatus = nogoSucceeded
	}

	// Extract the export data file and pack it in an .x archive together with the
	// nogo facts file (if there is one). This allows compile actions to depend
	// on .x files only, so we don't need to recompile a package when one of its
	// imports changes in a way that doesn't affect export data.
	// TODO(golang/go#33820): After Go 1.16 is the minimum supported version,
	// use -linkobj to tell the compiler to create separate .a and .x files for
	// compiled code and export data. Before that version, the linker needed
	// export data in the .a file when building a plugin. To work around that,
	// we copy the export data into .x ourselves.
	if err = extractFileFromArchive(outPath, workDir, pkgDef); err != nil {
		return err
	}
	pkgDefPath := filepath.Join(workDir, pkgDef)
	if nogoStatus == nogoSucceeded {
		return appendFiles(goenv, outXPath, []string{pkgDefPath, outFactsPath})
	}
	return appendFiles(goenv, outXPath, []string{pkgDefPath})
}

func compileGo(goenv *env, srcs []string, packagePath, importcfgPath, embedcfgPath, asmHdrPath, symabisPath string, gcFlags []string, outPath string) error {
	args := goenv.goTool("compile")
	args = append(args, "-p", packagePath, "-importcfg", importcfgPath, "-pack")
	if embedcfgPath != "" {
		args = append(args, "-embedcfg", embedcfgPath)
	}
	if asmHdrPath != "" {
		args = append(args, "-asmhdr", asmHdrPath)
	}
	if symabisPath != "" {
		args = append(args, "-symabis", symabisPath)
	}
	args = append(args, gcFlags...)
	args = append(args, "-o", outPath)
	args = append(args, "--")
	args = append(args, srcs...)
	absArgs(args, []string{"-I", "-o", "-trimpath", "-importcfg"})
	return goenv.runCommand(args)
}

func runNogo(ctx context.Context, workDir string, nogoPath string, srcs []string, deps []archive, packagePath, importcfgPath, outFactsPath string) error {
	args := []string{nogoPath}
	args = append(args, "-p", packagePath)
	args = append(args, "-importcfg", importcfgPath)
	for _, dep := range deps {
		args = append(args, "-fact", fmt.Sprintf("%s=%s", dep.importPath, dep.file))
	}
	args = append(args, "-x", outFactsPath)
	args = append(args, srcs...)

	paramsFile := filepath.Join(workDir, "nogo.param")
	if err := writeParamsFile(paramsFile, args[1:]); err != nil {
		return fmt.Errorf("error writing nogo params file: %v", err)
	}

	cmd := exec.CommandContext(ctx, args[0], "-param="+paramsFile)
	out := &bytes.Buffer{}
	cmd.Stdout, cmd.Stderr = out, out
	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			if !exitErr.Exited() {
				cmdLine := strings.Join(args, " ")
				return fmt.Errorf("nogo command '%s' exited unexpectedly: %s", cmdLine, exitErr.String())
			}
			return errors.New(string(relativizePaths(out.Bytes())))
		} else {
			if out.Len() != 0 {
				fmt.Fprintln(os.Stderr, out.String())
			}
			return fmt.Errorf("error running nogo: %v", err)
		}
	}
	return nil
}

func createTrimPath(gcFlags []string, path string) string {
	for _, flag := range gcFlags {
		if strings.HasPrefix(flag, "-trimpath=") {
			return flag + ":" + path
		}
	}

	return "-trimpath=" + path
}

func sanitizePathForIdentifier(path string) string {
	return strings.Map(func(r rune) rune {
		if 'A' <= r && r <= 'Z' ||
			'a' <= r && r <= 'z' ||
			'0' <= r && r <= '9' ||
			r == '_' {
			return r
		}
		return '_'
	}, path)
}
