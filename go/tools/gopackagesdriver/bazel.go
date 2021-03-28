package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

const (
	toolTag = "gopackagesdriver"
)

type Bazel struct {
	bazelBin      string
	execRoot      string
	workspaceRoot string
}

// Minimal BEP structs to access the build outputs
type BEPNamedSet struct {
	NamedSetOfFiles *struct {
		Files []struct {
			Name string `json:"name"`
			URI  string `json:"uri"`
		} `json:"files"`
	} `json:"namedSetOfFiles"`
}

func NewBazel(ctx context.Context, bazelBin, workspaceRoot string) (*Bazel, error) {
	b := &Bazel{
		bazelBin:      bazelBin,
		workspaceRoot: workspaceRoot,
	}
	if execRoot, err := b.run(ctx, "info", "execution_root"); err != nil {
		return nil, err
	} else {
		b.execRoot = strings.TrimSpace(execRoot)
	}
	return b, nil
}

func (b *Bazel) run(ctx context.Context, command string, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, b.bazelBin, append([]string{
		command,
		"--tool_tag=" + toolTag,
	}, args...)...)
	fmt.Fprintln(os.Stderr, "Running:", cmd.Args)
	cmd.Dir = b.workspaceRoot
	cmd.Stderr = os.Stderr
	output, err := cmd.Output()
	return string(output), err
}

func (b *Bazel) Build(ctx context.Context, args ...string) ([]string, error) {
	jsonTmp, _ := os.CreateTemp("", "bep_")
	jsonTmp.Close()
	defer os.RemoveAll(jsonTmp.Name())

	args = append([]string{
		"--build_event_json_file=" + jsonTmp.Name(),
		"--build_event_json_file_path_conversion=no",
	}, args...)
	if _, err := b.run(ctx, "build", args...); err != nil {
		return nil, err
	}

	jsonFile, err := os.Open(jsonTmp.Name())
	if err != nil {
		return nil, err
	}
	defer jsonFile.Close()

	files := make([]string, 0)
	decoder := json.NewDecoder(jsonFile)
	for decoder.More() {
		var namedSet BEPNamedSet
		if err := decoder.Decode(&namedSet); err != nil {
			panic(err)
		}
		if namedSet.NamedSetOfFiles != nil {
			for _, f := range namedSet.NamedSetOfFiles.Files {
				files = append(files, strings.TrimPrefix(f.URI, "file://"))
			}
		}
	}

	return files, nil
}

func (b *Bazel) Query(ctx context.Context, args ...string) ([]string, error) {
	output, err := b.run(ctx, "query", args...)
	if err != nil {
		return nil, err
	}
	return strings.Split(strings.TrimSpace(output), "\n"), nil
}

func (b *Bazel) WorkspaceRoot() string {
	return b.workspaceRoot
}

func (b *Bazel) ExecutionRoot() string {
	return b.execRoot
}
