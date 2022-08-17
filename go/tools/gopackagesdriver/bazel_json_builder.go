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
	"fmt"
	"path/filepath"
	"strings"
)

type BazelJSONBuilder struct {
	bazel    *Bazel
	requests []string
}

const (
	RulesGoStdlibLabel = "@io_bazel_rules_go//:stdlib"
)

func (b *BazelJSONBuilder) fileQuery(filename string) string {
	if filepath.IsAbs(filename) {
		fp, _ := filepath.Rel(b.bazel.WorkspaceRoot(), filename)
		filename = fp
	}
	return fmt.Sprintf(`kind("go_library|go_test|go_binary", same_pkg_direct_rdeps("%s"))`, filename)
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
	queryArgs := concatStringsArrays(bazelFlags, bazelQueryFlags, []string{
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

	buildArgs := concatStringsArrays([]string{
		"--experimental_convenience_symlinks=ignore",
		"--ui_event_filters=-info,-stderr",
		"--noshow_progress",
		"--aspects=" + rulesGoRepositoryName + "//go/tools/gopackagesdriver:aspect.bzl%go_pkg_info_aspect",
		"--output_groups=" + b.outputGroupsForMode(mode),
		"--keep_going", // Build all possible packages
	}, bazelFlags, bazelBuildFlags, labels)
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
