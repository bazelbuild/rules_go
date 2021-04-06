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
	OutputGroupDriverJSON  = "go_pkg_driver_json"
	OutputGroupStdLibJSON  = "go_pkg_driver_stdlib_json"
	OutputGroupExportFiles = "go_pkg_driver_x"
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
	og := OutputGroupDriverJSON + "," + OutputGroupStdLibJSON
	if mode&NeedExportsFile != 0 || true { // override for now
		og += "," + OutputGroupExportFiles
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
		if strings.HasSuffix(f, ".pkg.json") == false {
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
