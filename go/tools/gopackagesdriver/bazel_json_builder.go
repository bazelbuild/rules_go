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
	"bufio"
	"context"
	"errors"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

type BazelJSONBuilder struct {
	bazel    *Bazel
	requests []string
}

var RulesGoStdlibLabel = rulesGoRepositoryName + "//:stdlib"

var _defaultKinds = []string{"go_library", "go_test", "go_binary"}

var externalRe = regexp.MustCompile(".*\\/external\\/([^\\/]+)(\\/(.*))?\\/([^\\/]+.go)")

func (b *BazelJSONBuilder) fileQuery(filename string) string {
	label := filename

	if filepath.IsAbs(filename) {
		label, _ = filepath.Rel(b.bazel.WorkspaceRoot(), filename)
	}

	if matches := externalRe.FindStringSubmatch(filename); len(matches) == 5 {
		// if filepath is for a third party lib, we need to know, what external
		// library this file is part of.
		matches = append(matches[:2], matches[3:]...)
		label = fmt.Sprintf("@%s//%s", matches[1], strings.Join(matches[2:], ":"))
	}

	relToBin, err := filepath.Rel(b.bazel.info["output_path"], filename)
	if err == nil && !strings.HasPrefix(relToBin, "../") {
		parts := strings.SplitN(relToBin, string(filepath.Separator), 3)
		relToBin = parts[2]
		// We've effectively converted filename from bazel-bin/some/path.go to some/path.go;
		// Check if a BUILD.bazel files exists under this dir, if not walk up and repeat.
		relToBin = filepath.Dir(relToBin)
		_, err = os.Stat(filepath.Join(b.bazel.WorkspaceRoot(), relToBin, "BUILD.bazel"))
		for errors.Is(err, os.ErrNotExist) && relToBin != "." {
			relToBin = filepath.Dir(relToBin)
			_, err = os.Stat(filepath.Join(b.bazel.WorkspaceRoot(), relToBin, "BUILD.bazel"))
		}

		if err == nil {
			// return package path found and build all targets (codegen doesn't fall under go_library)
			// Otherwise fallback to default
			if relToBin == "." {
				relToBin = ""
			}
			label = fmt.Sprintf("//%s:all", relToBin)
			additionalKinds = append(additionalKinds, "go_.*")
		}
	}

	kinds := append(_defaultKinds, additionalKinds...)
	return fmt.Sprintf(`kind("%s", same_pkg_direct_rdeps("%s"))`, strings.Join(kinds, "|"), label)
}

func (b *BazelJSONBuilder) packageQuery(importPath string) string {
	if strings.HasSuffix(importPath, "/...") {
		importPath = fmt.Sprintf(`^%s(/.+)?$`, strings.TrimSuffix(importPath, "/..."))
	}
	return fmt.Sprintf(`kind("go_library", attr(importpath, "%s", deps(%s)))`, importPath, bazelQueryScope)
}

func (b *BazelJSONBuilder) queryFromRequests(requests ...string) string {
	ret := make([]string, 0, len(requests))
	for _, request := range requests {
		result := ""
		if request == "." || request == "./..." {
			if bazelQueryScope != "" {
				result = fmt.Sprintf(`kind("go_library", %s)`, bazelQueryScope)
			} else {
				result = fmt.Sprintf(RulesGoStdlibLabel)
			}
		} else if request == "builtin" || request == "std" {
			result = fmt.Sprintf(RulesGoStdlibLabel)
		} else if strings.HasPrefix(request, "file=") {
			f := strings.TrimPrefix(request, "file=")
			result = b.fileQuery(f)
		} else if bazelQueryScope != "" {
			result = b.packageQuery(request)
		}
		if result != "" {
			ret = append(ret, result)
		}
	}
	if len(ret) == 0 {
		return RulesGoStdlibLabel
	}
	return strings.Join(ret, " union ")
}

func NewBazelJSONBuilder(bazel *Bazel, requests ...string) (*BazelJSONBuilder, error) {
	return &BazelJSONBuilder{
		bazel:    bazel,
		requests: requests,
	}, nil
}

func (b *BazelJSONBuilder) outputGroupsForMode(mode LoadMode) string {
	og := "go_pkg_driver_json_file,go_pkg_driver_stdlib_json_file,go_pkg_driver_srcs"
	if mode&NeedExportsFile != 0 {
		og += ",go_pkg_driver_export_file"
	}
	return og
}

func (b *BazelJSONBuilder) query(ctx context.Context, query string) ([]string, error) {
	queryArgs := concatStringsArrays(bazelQueryFlags, []string{
		"--ui_event_filters=-info,-stderr",
		"--noshow_progress",
		"--order_output=no",
		"--output=label",
		"--nodep_deps",
		"--noimplicit_deps",
		"--notool_deps",
		query,
	})
	labels, err := b.bazel.Query(ctx, queryArgs...)
	if err != nil {
		return nil, fmt.Errorf("unable to query: %w", err)
	}
	return labels, nil
}

func (b *BazelJSONBuilder) Build(ctx context.Context, mode LoadMode) ([]string, error) {
	labels, err := b.query(ctx, b.queryFromRequests(b.requests...))
	if err != nil {
		return nil, fmt.Errorf("query failed: %w", err)
	}

	if len(labels) == 0 {
		return nil, fmt.Errorf("found no labels matching the requests")
	}

	aspects := append(additionalAspects, goDefaultAspect)

	buildArgs := concatStringsArrays([]string{
		"--experimental_convenience_symlinks=ignore",
		"--ui_event_filters=-info,-stderr",
		"--noshow_progress",
		"--aspects=" + strings.Join(aspects, ","),
		"--output_groups=" + b.outputGroupsForMode(mode),
		"--keep_going", // Build all possible packages
	}, bazelBuildFlags)

	if len(labels) < 100 {
		buildArgs = append(buildArgs, labels...)
	} else {
		// To avoid hitting MAX_ARGS length, write labels to a file and use `--target_pattern_file`
		targetsFile, err := ioutil.TempFile("", "gopackagesdriver_targets_")
		if err != nil {
			return nil, fmt.Errorf("unable to create target pattern file: %w", err)
		}
		writer := bufio.NewWriter(targetsFile)
		defer writer.Flush()
		for _, l := range labels {
			writer.WriteString(l+"\n")
		}
		if err := writer.Flush(); err != nil {
			return nil, fmt.Errorf("unable to flush data to target pattern file: %w", err)
		}
		defer func() {
			targetsFile.Close()
			os.Remove(targetsFile.Name())
		}()

		buildArgs = append(buildArgs, "--target_pattern_file="+targetsFile.Name())
	}
	files, err := b.bazel.Build(ctx, buildArgs...)
	if err != nil {
		return nil, fmt.Errorf("unable to bazel build %v: %w", buildArgs, err)
	}

	ret := []string{}
	for _, f := range files {
		if strings.HasSuffix(f, ".pkg.json") {
			ret = append(ret, f)
		}
	}

	return ret, nil
}

func (b *BazelJSONBuilder) PathResolver() PathResolverFunc {
	return func(p string) string {
		p = strings.Replace(p, "__BAZEL_EXECROOT__", b.bazel.ExecutionRoot(), 1)
		p = strings.Replace(p, "__BAZEL_WORKSPACE__", b.bazel.WorkspaceRoot(), 1)
		p = strings.Replace(p, "__BAZEL_OUTPUT_BASE__", b.bazel.OutputBase(), 1)
		return p
	}
}
