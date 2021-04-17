// Copyright 2021 The Bazel Authors. All rights reserved.
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
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
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
		"--show_result=0",
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
				fileUrl, err := url.Parse(f.URI)
				if err != nil {
					return nil, fmt.Errorf("unable to parse file URI: %w", err)
				}
				files = append(files, filepath.FromSlash(fileUrl.Path))
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
