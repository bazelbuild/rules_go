package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
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
		return nil, fmt.Errorf("unable to find execution root: %w", err)
	} else {
		b.execRoot = strings.TrimSpace(execRoot)
	}
	return b, nil
}

func (b *Bazel) run(ctx context.Context, command string, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, b.bazelBin, append([]string{
		command,
		"--tool_tag=" + toolTag,
		"--show_result=0",
		"--ui_actions_shown=0",
	}, args...)...)
	fmt.Fprintln(os.Stderr, "Running:", cmd.Args)
	cmd.Dir = b.workspaceRoot
	cmd.Stderr = os.Stderr
	output, err := cmd.Output()
	return string(output), err
}

func (b *Bazel) Build(ctx context.Context, args ...string) ([]string, error) {
	jsonFile, err := ioutil.TempFile("", "gopackagesdriver_bep_")
	if err != nil {
		return nil, fmt.Errorf("unable to create BEP JSON file: %w", err)
	}
	defer func() {
		jsonFile.Close()
		os.Remove(jsonFile.Name())
	}()

	args = append([]string{
		"--build_event_json_file=" + jsonFile.Name(),
		"--build_event_json_file_path_conversion=no",
	}, args...)
	if _, err := b.run(ctx, "build", args...); err != nil {
		return nil, fmt.Errorf("bazel build failed: %w", err)
	}

	files := make([]string, 0)
	decoder := json.NewDecoder(jsonFile)
	for decoder.More() {
		var namedSet BEPNamedSet
		if err := decoder.Decode(&namedSet); err != nil {
			return nil, fmt.Errorf("unable to decode %s: %w", jsonFile.Name(), err)
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
		return nil, fmt.Errorf("bazel query failed: %w", err)
	}
	return strings.Split(strings.TrimSpace(output), "\n"), nil
}

func (b *Bazel) WorkspaceRoot() string {
	return b.workspaceRoot
}

func (b *Bazel) ExecutionRoot() string {
	return b.execRoot
}
