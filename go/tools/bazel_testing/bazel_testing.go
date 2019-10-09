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

// Package bazel_testing provides an integration testing framework for
// testing rules_go with Bazel.
//
// Tests may be written by declaring a go_bazel_test target instead of
// a go_test (go_bazel_test is defined in def.bzl here), then calling
// TestMain. Tests are run in a synthetic test workspace. Tests may run
// bazel commands with RunBazel.
package bazel_testing

import (
	"bytes"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"os/exec"
	"os/signal"
	"path"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"testing"
	"text/template"

	"github.com/bazelbuild/rules_go/go/tools/bazel"
	"github.com/bazelbuild/rules_go/go/tools/internal/txtar"
)

// Args is a list of arguments to TestMain. It's defined as a struct so
// that new optional arguments may be added without breaking compatibility.
type Args struct {
	// Main is a text archive containing files in the main workspace.
	// The text archive format is parsed by
	// //go/tools/internal/txtar:go_default_library, which is copied from
	// cmd/go/internal/txtar. If this archive does not contain a WORKSPACE file,
	// a default file will be synthesized.
	Main string

	// Nogo is the nogo target to pass to go_register_toolchains. By default,
	// nogo is not used.
	Nogo string

	// WorkspaceSuffix is a string that should be appended to the end
	// of the default generated WORKSPACE file.
	WorkspaceSuffix string
}

// debug may be set to make the test print the test workspace path and stop
// instead of running tests.
const debug = false

// TestMain should be called by tests using this framework from a function named
// "TestMain". For example:
//
//     func TestMain(m *testing.M) {
//       os.Exit(bazel_testing.TestMain(m, bazel_testing.Args{...}))
//     }
//
// TestMain constructs a set of workspaces and changes the working directory to
// the main workspace.
func TestMain(m *testing.M, args Args) {
	// Defer os.Exit with the correct code. This ensures other deferred cleanup
	// functions are run first.
	code := 1
	defer func() {
		if r := recover(); r != nil {
			fmt.Fprintf(os.Stderr, "panic: %v\n", r)
			code = 1
		}
		os.Exit(code)
	}()

	var files []string
	beginFiles, endFiles := -1, -1
	for i, arg := range os.Args {
		if arg == "-begin_files" {
			beginFiles = i
		} else if arg == "-end_files" {
			endFiles = i
			break
		} else if arg == "--" {
			break
		}
	}
	if beginFiles >= 0 && endFiles < 0 ||
		beginFiles < 0 && endFiles >= 0 ||
		beginFiles >= 0 && beginFiles >= endFiles {
		fmt.Fprintf(os.Stderr, "error: -begin_files, -end_files not set together or in order\n")
		return
	}
	if beginFiles >= 0 {
		files = os.Args[beginFiles+1 : endFiles-1]
		os.Args = append(os.Args[:beginFiles:beginFiles], os.Args[endFiles+1:]...)
	}

	flag.Parse()

	workspaceDir, cleanup, err := setupWorkspace(args, files)
	defer func() {
		if err := cleanup(); err != nil {
			fmt.Fprintf(os.Stderr, "cleanup error: %v\n", err)
			// Don't fail the test on a cleanup error.
			// Some operating systems (windows, maybe also darwin) can't reliably
			// delete executable files after they're run.
		}
	}()
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		return
	}

	if debug {
		fmt.Fprintf(os.Stderr, "test setup in %s\n", workspaceDir)
		interrupted := make(chan os.Signal)
		signal.Notify(interrupted, os.Interrupt)
		<-interrupted
		return
	}

	if err := os.Chdir(workspaceDir); err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		return
	}
	defer exec.Command("bazel", "shutdown").Run()

	code = m.Run()
}

// BazelCmd prepares a bazel command for execution. It chooses the correct
// bazel binary based on the environment and sanitizes the environment to
// hide that this code is executing inside a bazel test.
func BazelCmd(args ...string) *exec.Cmd {
	cmd := exec.Command("bazel", args...)
	for _, e := range os.Environ() {
		// Filter environment variables set by the bazel test wrapper script.
		// These confuse recursive invocations of Bazel.
		if strings.HasPrefix(e, "TEST_") || strings.HasPrefix(e, "RUNFILES_") {
			continue
		}
		cmd.Env = append(cmd.Env, e)
	}
	return cmd
}

// RunBazel invokes a bazel command with a list of arguments.
//
// If the command starts but exits with a non-zero status, a *StderrExitError
// will be returned which wraps the original *exec.ExitError.
func RunBazel(args ...string) error {
	cmd := BazelCmd(args...)

	buf := &bytes.Buffer{}
	cmd.Stderr = buf
	err := cmd.Run()
	if eErr, ok := err.(*exec.ExitError); ok {
		eErr.Stderr = buf.Bytes()
		err = &StderrExitError{Err: eErr}
	}
	return err
}

// BazelOutput invokes a bazel command with a list of arguments and returns
// the content of stdout.
//
// If the command starts but exits with a non-zero status, a *StderrExitError
// will be returned which wraps the original *exec.ExitError.
func BazelOutput(args ...string) ([]byte, error) {
	cmd := BazelCmd(args...)
	stdout := &bytes.Buffer{}
	stderr := &bytes.Buffer{}
	cmd.Stdout = stdout
	cmd.Stderr = stderr
	err := cmd.Run()
	if eErr, ok := err.(*exec.ExitError); ok {
		eErr.Stderr = stderr.Bytes()
		err = &StderrExitError{Err: eErr}
	}
	return stdout.Bytes(), err
}

// StderrExitError wraps *exec.ExitError and prints the complete stderr output
// from a command.
type StderrExitError struct {
	Err *exec.ExitError
}

func (e *StderrExitError) Error() string {
	sb := &strings.Builder{}
	sb.Write(e.Err.Stderr)
	sb.WriteString(e.Err.Error())
	return sb.String()
}

func setupWorkspace(args Args, files []string) (dir string, cleanup func() error, err error) {
	var cleanups []func() error
	cleanup = func() error {
		var firstErr error
		for i := len(cleanups) - 1; i >= 0; i-- {
			if err := cleanups[i](); err != nil && firstErr == nil {
				firstErr = err
			}
		}
		return firstErr
	}
	defer func() {
		if err != nil {
			cleanup()
			cleanup = func() error { return nil }
		}
	}()

	// Find a suitable cache directory. We want something persistent where we
	// can store a bazel output base across test runs, even for multiple tests.
	var cacheDir, outBaseDir string
	if tmpDir := os.Getenv("TEST_TMPDIR"); tmpDir != "" {
		// TEST_TMPDIR is set by Bazel's test wrapper. Bazel itself uses this to
		// detect that it's run by a test. When invoked like this, Bazel sets
		// its output base directory to a temporary directory. This wastes a lot
		// of time (a simple test takes 45s instead of 3s). We use TEST_TMPDIR
		// to find a persistent location in the execroot. We won't pass TEST_TMPDIR
		// to bazel in RunBazel.
		tmpDir = filepath.Clean(tmpDir)
		if i := strings.Index(tmpDir, string(os.PathSeparator)+"execroot"+string(os.PathSeparator)); i >= 0 {
			outBaseDir = tmpDir[:i]
			cacheDir = filepath.Join(outBaseDir, "bazel_testing")
		} else {
			cacheDir = filepath.Join(tmpDir, "bazel_testing")
		}
	} else {
		// The test is not invoked by Bazel, so just use the user's cache.
		cacheDir, err = os.UserCacheDir()
		if err != nil {
			return "", cleanup, err
		}
		cacheDir = filepath.Join(cacheDir, "bazel_testing")
	}

	// TODO(jayconrod): any other directories needed for caches?
	execDir := filepath.Join(cacheDir, "bazel_go_test")
	if err := os.RemoveAll(execDir); err != nil {
		return "", cleanup, err
	}
	cleanups = append(cleanups, func() error { return os.RemoveAll(execDir) })

	// Extract test files for the main workspace.
	mainDir := filepath.Join(execDir, "main")
	if err := os.MkdirAll(mainDir, 0777); err != nil {
		return "", cleanup, err
	}
	if err := extractTxtar(mainDir, args.Main); err != nil {
		return "", cleanup, fmt.Errorf("building main workspace: %v", err)
	}

	// Copy or data files for rules_go, or whatever was passed in.
	runfiles, err := bazel.ListRunfiles()
	if err != nil {
		return "", cleanup, err
	}
	type runfileKey struct{ workspace, short string }
	runfileMap := make(map[runfileKey]string)
	for _, rf := range runfiles {
		runfileMap[runfileKey{rf.Workspace, rf.ShortPath}] = rf.Path
	}
	workspaceNames := make(map[string]bool)
	for _, argPath := range files {
		shortPath := path.Clean(argPath)
		if !strings.HasPrefix(shortPath, "external/") {
			return "", cleanup, fmt.Errorf("unexpected file: %s", argPath)
		}
		shortPath = shortPath[len("external/"):]
		var workspace string
		if i := strings.IndexByte(shortPath, '/'); i < 0 {
			return "", cleanup, fmt.Errorf("unexpected file: %s", argPath)
		} else {
			workspace = shortPath[:i]
			shortPath = shortPath[i+1:]
		}
		workspaceNames[workspace] = true
		srcPath, ok := runfileMap[runfileKey{workspace, shortPath}]
		if !ok {
			return "", cleanup, fmt.Errorf("unknown runfile: %s", argPath)
		}

		dstPath := filepath.Join(execDir, workspace, shortPath)
		if err := copyOrLink(dstPath, srcPath); err != nil {
			return "", cleanup, err
		}
	}

	// If there's no WORKSPACE file, create one.
	workspacePath := filepath.Join(mainDir, "WORKSPACE")
	if _, err := os.Stat(workspacePath); os.IsNotExist(err) {
		w, err := os.Create(workspacePath)
		if err != nil {
			return "", cleanup, err
		}
		defer func() {
			if cerr := w.Close(); err == nil && cerr != nil {
				err = cerr
			}
		}()
		info := workspaceTemplateInfo{
			Suffix: args.WorkspaceSuffix,
			Nogo:   args.Nogo,
		}
		for name := range workspaceNames {
			info.WorkspaceNames = append(info.WorkspaceNames, name)
		}
		sort.Strings(info.WorkspaceNames)
		if outBaseDir != "" {
			goSDKPath := filepath.Join(outBaseDir, "external", "go_sdk")
			rel, err := filepath.Rel(mainDir, goSDKPath)
			if err != nil {
				return "", cleanup, fmt.Errorf("could not find relative path from %q to %q for go_sdk", mainDir, goSDKPath)
			}
			rel = filepath.ToSlash(rel)
			info.GoSDKPath = rel
		}
		if err := defaultWorkspaceTpl.Execute(w, info); err != nil {
			return "", cleanup, err
		}
	}

	return mainDir, cleanup, nil
}

func extractTxtar(dir, txt string) error {
	ar := txtar.Parse([]byte(txt))
	for _, f := range ar.Files {
		if err := ioutil.WriteFile(filepath.Join(dir, f.Name), f.Data, 0666); err != nil {
			return err
		}
	}
	return nil
}

type workspaceTemplateInfo struct {
	WorkspaceNames []string
	GoSDKPath      string
	Nogo           string
	Suffix         string
}

var defaultWorkspaceTpl = template.Must(template.New("").Parse(`
{{range .WorkspaceNames}}
local_repository(
    name = "{{.}}",
    path = "../{{.}}",
)
{{end}}

{{if not .GoSDKPath}}
load("@io_bazel_rules_go//go:deps.bzl", "go_rules_dependencies", "go_register_toolchains")

go_rules_dependencies()

go_register_toolchains(go_version = "host")
{{else}}
local_repository(
    name = "local_go_sdk",
    path = "{{.GoSDKPath}}",
)

load("@io_bazel_rules_go//go:deps.bzl", "go_rules_dependencies", "go_register_toolchains", "go_wrap_sdk")

go_rules_dependencies()

go_wrap_sdk(
    name = "go_sdk",
    root_file = "@local_go_sdk//:ROOT",
)

go_register_toolchains({{if .Nogo}}nogo = "{{.Nogo}}"{{end}})
{{end}}
{{.Suffix}}
`))

func copyOrLink(dstPath, srcPath string) error {
	if err := os.MkdirAll(filepath.Dir(dstPath), 0777); err != nil {
		return err
	}

	copy := func(dstPath, srcPath string) (err error) {
		src, err := os.Open(srcPath)
		if err != nil {
			return err
		}
		defer src.Close()

		dst, err := os.Create(dstPath)
		if err != nil {
			return err
		}
		defer func() {
			if cerr := dst.Close(); err == nil && cerr != nil {
				err = cerr
			}
		}()

		_, err = io.Copy(dst, src)
		return err
	}

	if runtime.GOOS == "windows" {
		return copy(dstPath, srcPath)
	}
	absSrcPath, err := filepath.Abs(srcPath)
	if err != nil {
		return err
	}
	return os.Symlink(absSrcPath, dstPath)
}
