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
	"strings"
)

type BazelJSONBuilder struct {
	bazel      *Bazel
	query      string
	tagFilters string
	targets    []string
}

const (
	OutputGroupDriverJSONFile = "go_pkg_driver_json_file"
	OutputGroupStdLibJSONFile = "go_pkg_driver_stdlib_json_file"
	OutputGroupExportFile     = "go_pkg_driver_export_file"
)

func NewBazelJSONBuilder(bazel *Bazel, query, tagFilters string, targets []string) (*BazelJSONBuilder, error) {
	return &BazelJSONBuilder{
		bazel:      bazel,
		query:      query,
		tagFilters: tagFilters,
		targets:    targets,
	}, nil
}

func (b *BazelJSONBuilder) outputGroupsForMode(mode LoadMode) string {
	og := OutputGroupDriverJSONFile + "," + OutputGroupStdLibJSONFile
	if mode&NeedExportsFile != 0 || true { // override for now
		og += "," + OutputGroupExportFile
	}
	return og
}

func (b *BazelJSONBuilder) Build(ctx context.Context, mode LoadMode) ([]string, error) {
	buildsArgs := []string{
		"--aspects=@io_bazel_rules_go//go/tools/gopackagesdriver:aspect.bzl%go_pkg_info_aspect",
		"--output_groups=" + b.outputGroupsForMode(mode),
		"--keep_going", // Build all possible packages
	}

	if b.tagFilters != "" {
		buildsArgs = append(buildsArgs, "--build_tag_filters="+b.tagFilters)
	}

	if b.query != "" {
		queryTargets, err := b.bazel.Query(
			ctx,
			"--order_output=no",
			"--output=label",
			"--experimental_graphless_query",
			"--nodep_deps",
			"--noimplicit_deps",
			"--notool_deps",
			b.query,
		)
		if err != nil {
			return nil, fmt.Errorf("unable to query %v: %w", b.query, err)
		}
		buildsArgs = append(buildsArgs, queryTargets...)
	}

	buildsArgs = append(buildsArgs, b.targets...)

	files, err := b.bazel.Build(ctx, buildsArgs...)
	if err != nil {
		return nil, fmt.Errorf("unable to bazel build %v: %w", buildsArgs, err)
	}

	ret := []string{}
	for _, f := range files {
		if !strings.HasSuffix(f, ".pkg.json") {
			continue
		}
		ret = append(ret, f)
	}

	return ret, nil
}

func (b *BazelJSONBuilder) PathResolver() PathResolverFunc {
	return func(p string) string {
		p = strings.Replace(p, "__BAZEL_EXECROOT__", b.bazel.ExecutionRoot(), 1)
		p = strings.Replace(p, "__BAZEL_WORKSPACE__", b.bazel.WorkspaceRoot(), 1)
		return p
	}
}
