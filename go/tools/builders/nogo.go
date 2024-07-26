package main

import (
	"bytes"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func nogo(args []string) error {
	// Parse arguments.
	args, _, err := expandParamsFiles(args)
	if err != nil {
		return err
	}

	fs := flag.NewFlagSet("GoNogo", flag.ExitOnError)
	goenv := envFlags(fs)
	var unfilteredSrcs multiFlag
	var deps, facts archiveMultiFlag
	var importPath, packagePath, nogoPath, packageListPath string
	var outFactsPath string
	fs.Var(&unfilteredSrcs, "src", ".go, .c, .cc, .m, .mm, .s, or .S file to be filtered and compiled")
	fs.Var(&deps, "arc", "Import path, package path, and file name of a direct dependency, separated by '='")
	fs.Var(&facts, "facts", "Import path, package path, and file name of a direct dependency's nogo facts file, separated by '='")
	fs.StringVar(&importPath, "importpath", "", "The import path of the package being compiled. Not passed to the compiler, but may be displayed in debug data.")
	fs.StringVar(&packagePath, "p", "", "The package path (importmap) of the package being compiled")
	fs.StringVar(&packageListPath, "package_list", "", "The file containing the list of standard library packages")
	fs.StringVar(&nogoPath, "nogo", "", "The nogo binary. If unset, nogo will not be run.")
	fs.StringVar(&outFactsPath, "out_facts", "", "The file to emit serialized nogo facts to (must be set if -nogo is set")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if err := goenv.checkFlagsAndSetGoroot(); err != nil {
		return err
	}
	if importPath == "" {
		importPath = packagePath
	}

	// Filter sources.
	srcs, err := filterAndSplitFiles(unfilteredSrcs)
	if err != nil {
		return err
	}

	var goSrcs []string
	haveCgo := false
	for _, src := range srcs.goSrcs {
		if src.isCgo {
			haveCgo = true
		} else {
			goSrcs = append(goSrcs, src.filename)
		}
	}

	workDir, cleanup, err := goenv.workDir()
	if err != nil {
		return err
	}
	defer cleanup()

	imports, err := checkImports(srcs.goSrcs, deps, packageListPath, importPath, []string{})
	if err != nil {
		return err
	}
	cgoEnabled := os.Getenv("CGO_ENABLED") == "1"
	if haveCgo && cgoEnabled {
		// cgo generated code imports some extra packages.
		imports["runtime/cgo"] = nil
		imports["syscall"] = nil
		imports["unsafe"] = nil
	}

	importcfgPath, err := buildImportcfgFileForCompile(imports, goenv.installSuffix, filepath.Dir(outFactsPath))
	if err != nil {
		return err
	}
	if !goenv.shouldPreserveWorkDir {
		defer os.Remove(importcfgPath)
	}

	return runNogo(workDir, nogoPath, goSrcs, facts, importPath, importcfgPath, outFactsPath)
}

func runNogo(workDir string, nogoPath string, srcs []string, facts []archive, packagePath, importcfgPath, outFactsPath string) error {
	if len(srcs) == 0 {
		// emit_compilepkg expects a nogo facts file, even if it's empty.
		return os.WriteFile(outFactsPath, nil, 0o666)
	}
	args := []string{nogoPath}
	args = append(args, "-p", packagePath)
	args = append(args, "-importcfg", importcfgPath)
	for _, fact := range facts {
		args = append(args, "-fact", fmt.Sprintf("%s=%s", fact.importPath, fact.file))
	}
	args = append(args, "-x", outFactsPath)
	args = append(args, srcs...)

	paramsFile := filepath.Join(workDir, "nogo.param")
	if err := writeParamsFile(paramsFile, args[1:]); err != nil {
		return fmt.Errorf("error writing nogo params file: %v", err)
	}

	cmd := exec.Command(args[0], "-param="+paramsFile)
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

