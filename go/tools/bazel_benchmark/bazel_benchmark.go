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

package main

import (
	"bytes"
	"encoding/csv"
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"text/template"
	"time"
)

var programName = filepath.Base(os.Args[0])

type substitutions struct {
	RulesGoDir string
}

type serverState int

const (
	asleep serverState = iota
	awake
)

type cleanState int

const (
	clean cleanState = iota
	incr
)

type benchmark struct {
	desc        string
	serverState serverState
	cleanState  cleanState
	incrFile    string
	targets     []string
	result      time.Duration
}

var benchmarks = []benchmark{
	{
		desc:        "hello_asleep_clean",
		serverState: asleep,
		cleanState:  clean,
		targets:     []string{"//:hello"},
	}, {
		desc:        "hello_awake_clean",
		serverState: awake,
		cleanState:  clean,
		targets:     []string{"//:hello"},
	}, {
		desc:        "hello_asleep_incr",
		serverState: asleep,
		cleanState:  incr,
		incrFile:    "hello.go",
		targets:     []string{"//:hello"},
	}, {
		desc:        "hello_awake_incr",
		serverState: awake,
		cleanState:  incr,
		incrFile:    "hello.go",
		targets:     []string{"//:hello"},
	}, {
		desc:        "popular_repos_awake_clean",
		serverState: awake,
		cleanState:  clean,
		targets:     []string{"@io_bazel_rules_go//tests/integration/popular_repos:all"},
	},
	// TODO: more substantial Kubernetes targets
}

func main() {
	log.SetFlags(0)
	log.SetPrefix(programName + ": ")
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}

func run(args []string) error {
	fs := flag.NewFlagSet(programName, flag.ExitOnError)
	var rulesGoDir, outPath string
	fs.StringVar(&rulesGoDir, "rules_go_dir", "", "directory where rules_go is checked out")
	fs.StringVar(&outPath, "out", "", "csv file to append results to")
	var keep bool
	fs.BoolVar(&keep, "keep", false, "if true, the workspace directory won't be deleted at the end")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if rulesGoDir == "" {
		return errors.New("-rules_go_dir not set")
	}
	if abs, err := filepath.Abs(rulesGoDir); err != nil {
		return err
	} else {
		rulesGoDir = abs
	}
	if outPath == "" {
		return errors.New("-out not set")
	}
	if abs, err := filepath.Abs(outPath); err != nil {
		return err
	} else {
		outPath = abs
	}

	commit, err := getCommit(rulesGoDir)
	if err != nil {
		return err
	}

	dir, err := setupWorkspace(rulesGoDir)
	if err != nil {
		return err
	}
	if !keep {
		defer cleanupWorkspace(dir)
	}

	bazelVersion, err := getBazelVersion()
	if err != nil {
		return err
	}

	log.Printf("running benchmarks in %s", dir)
	targetSet := make(map[string]bool)
	for _, b := range benchmarks {
		for _, t := range b.targets {
			targetSet[t] = true
		}
	}
	allTargets := make([]string, 0, len(targetSet))
	for t := range targetSet {
		allTargets = append(allTargets, t)
	}
	fetch(allTargets)

	for i := range benchmarks {
		b := &benchmarks[i]
		log.Printf("running benchmark %d/%d: %s", i+1, len(benchmarks), b.desc)
		if err := runBenchmark(b); err != nil {
			return fmt.Errorf("error running benchmark %s: %v", b.desc, err)
		}
	}

	log.Printf("writing results to %s", outPath)
	return recordResults(outPath, time.Now().UTC(), bazelVersion, commit, benchmarks)
}

func getCommit(rulesGoDir string) (commit string, err error) {
	wd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	if err := os.Chdir(rulesGoDir); err != nil {
		return "", err
	}
	defer func() {
		if cderr := os.Chdir(wd); cderr != nil {
			if err != nil {
				err = cderr
			}
		}
	}()
	out, err := exec.Command("git", "rev-parse", "HEAD").Output()
	if err != nil {
		return "", err
	}
	outStr := strings.TrimSpace(string(out))
	if len(outStr) < 7 {
		return "", errors.New("git output too short")
	}
	return outStr[:7], nil
}

func setupWorkspace(rulesGoDir string) (workspaceDir string, err error) {
	workspaceDir, err = ioutil.TempDir("", "bazel_benchmark")
	if err != nil {
		return "", err
	}
	defer func() {
		if err != nil {
			os.RemoveAll(workspaceDir)
		}
	}()
	benchmarkDir := filepath.Join(rulesGoDir, "go", "tools", "bazel_benchmark")
	files, err := ioutil.ReadDir(benchmarkDir)
	if err != nil {
		return "", err
	}
	substitutions := substitutions{
		RulesGoDir: filepath.Join(benchmarkDir, "..", "..", ".."),
	}
	for _, f := range files {
		name := f.Name()
		if filepath.Ext(name) != ".in" {
			continue
		}
		srcPath := filepath.Join(benchmarkDir, name)
		tpl, err := template.ParseFiles(srcPath)
		if err != nil {
			return "", err
		}
		dstPath := filepath.Join(workspaceDir, name[:len(name)-len(".in")])
		out, err := os.Create(dstPath)
		if err != nil {
			return "", err
		}
		if err := tpl.Execute(out, substitutions); err != nil {
			out.Close()
			return "", err
		}
		if err := out.Close(); err != nil {
			return "", err
		}
	}
	if err := os.Chdir(workspaceDir); err != nil {
		return "", err
	}
	return workspaceDir, nil
}

func cleanupWorkspace(dir string) error {
	if err := logBazelCommand("clean", "--expunge"); err != nil {
		return err
	}
	return os.RemoveAll(dir)
}

func getBazelVersion() (string, error) {
	out, err := exec.Command("bazel", "version").Output()
	if err != nil {
		return "", err
	}
	prefix := []byte("Build label: ")
	i := bytes.Index(out, prefix)
	if i < 0 {
		return "", errors.New("could not find bazel version in output")
	}
	out = out[i+len(prefix):]
	i = bytes.IndexByte(out, '\n')
	if i >= 0 {
		out = out[:i]
	}
	return string(out), nil
}

func fetch(targets []string) error {
	return logBazelCommand("fetch", targets...)
}

func runBenchmark(b *benchmark) error {
	switch b.cleanState {
	case clean:
		if err := logBazelCommand("clean"); err != nil {
			return err
		}
	case incr:
		if err := logBazelCommand("build", b.targets...); err != nil {
			return err
		}
		if b.incrFile == "" {
			return errors.New("incrFile not set")
		}
		data, err := ioutil.ReadFile(b.incrFile)
		if err != nil {
			return err
		}
		data = bytes.Replace(data, []byte("INCR"), []byte("INCR."), -1)
		if err := ioutil.WriteFile(b.incrFile, data, 0666); err != nil {
			return err
		}
	}
	if b.serverState == asleep {
		if err := logBazelCommand("shutdown"); err != nil {
			return err
		}
	}
	start := time.Now()
	if err := logBazelCommand("build", b.targets...); err != nil {
		return err
	}
	b.result = time.Since(start)
	return nil
}

func recordResults(outPath string, t time.Time, bazelVersion, commit string, benchmarks []benchmark) (err error) {
	// TODO(jayconrod): update the header if new columns are added.
	columnMap, outExists, err := buildColumnMap(outPath, benchmarks)
	header := buildHeader(columnMap)
	record := buildRecord(t, bazelVersion, commit, benchmarks, columnMap)
	defer func() {
		if err != nil {
			log.Printf("error writing results: %s: %v", outPath, err)
			log.Print("data are printed below")
			log.Print(strings.Join(header, ","))
			log.Print(strings.Join(record, ","))
		}
	}()
	outFile, err := os.OpenFile(outPath, os.O_WRONLY|os.O_APPEND|os.O_CREATE, 0666)
	if err != nil {
		return err
	}
	defer func() {
		if cerr := outFile.Close(); err != nil {
			err = cerr
		}
	}()
	outCsv := csv.NewWriter(outFile)
	if !outExists {
		outCsv.Write(header)
	}
	outCsv.Write(record)
	outCsv.Flush()
	return outCsv.Error()
}

func logBazelCommand(command string, args ...string) error {
	args = append([]string{command}, args...)
	cmd := exec.Command("bazel", args...)
	log.Printf("bazel %s\n", strings.Join(args, " "))
	cmd.Stdout = os.Stderr
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func buildColumnMap(outPath string, benchmarks []benchmark) (columnMap map[string]int, outExists bool, err error) {
	columnMap = make(map[string]int)
	{
		inFile, oerr := os.Open(outPath)
		if oerr != nil {
			goto doneReading
		}
		outExists = true
		defer inFile.Close()
		inCsv := csv.NewReader(inFile)
		var header []string
		header, err = inCsv.Read()
		if err != nil {
			goto doneReading
		}
		for i, column := range header {
			columnMap[column] = i
		}
	}

doneReading:
	for _, s := range []string{"time", "bazel_version", "commit"} {
		if _, ok := columnMap[s]; !ok {
			columnMap[s] = len(columnMap)
		}
	}
	for _, b := range benchmarks {
		if _, ok := columnMap[b.desc]; !ok {
			columnMap[b.desc] = len(columnMap)
		}
	}
	return columnMap, outExists, err
}

func buildHeader(columnMap map[string]int) []string {
	header := make([]string, len(columnMap))
	for name, i := range columnMap {
		header[i] = name
	}
	return header
}

func buildRecord(t time.Time, bazelVersion, commit string, benchmarks []benchmark, columnMap map[string]int) []string {
	record := make([]string, len(columnMap))
	record[columnMap["time"]] = t.Format("2006-01-02 15:04:05")
	record[columnMap["bazel_version"]] = bazelVersion
	record[columnMap["commit"]] = commit
	for _, b := range benchmarks {
		record[columnMap[b.desc]] = fmt.Sprintf("%.3f", b.result.Seconds())
	}
	return record
}
