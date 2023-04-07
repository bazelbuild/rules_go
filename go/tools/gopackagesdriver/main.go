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
	"go/types"
	"os"
	"strings"
)

type driverResponse struct {
	// NotHandled is returned if the request can't be handled by the current
	// driver. If an external driver returns a response with NotHandled, the
	// rest of the driverResponse is ignored, and go/packages will fallback
	// to the next driver. If go/packages is extended in the future to support
	// lists of multiple drivers, go/packages will fall back to the next driver.
	NotHandled bool

	// Sizes, if not nil, is the types.Sizes to use when type checking.
	Sizes *types.StdSizes

	// Roots is the set of package IDs that make up the root packages.
	// We have to encode this separately because when we encode a single package
	// we cannot know if it is one of the roots as that requires knowledge of the
	// graph it is part of.
	Roots []string `json:",omitempty"`

	// Packages is the full set of packages in the graph.
	// The packages are not connected into a graph.
	// The Imports if populated will be stubs that only have their ID set.
	// Imports will be connected and then type and syntax information added in a
	// later pass (see refine).
	Packages []*FlatPackage
}

var (
	// Injected via x_defs.

	rulesGoRepositoryName string
	goDefaultAspect       = rulesGoRepositoryName + "//go/tools/gopackagesdriver:aspect.bzl%go_pkg_info_aspect"
	bazelBin              = getenvDefault("GOPACKAGESDRIVER_BAZEL", "bazel")
	bazelStartupFlags     = strings.Fields(os.Getenv("GOPACKAGESDRIVER_BAZEL_FLAGS"))
	bazelQueryFlags       = strings.Fields(os.Getenv("GOPACKAGESDRIVER_BAZEL_QUERY_FLAGS"))
	bazelQueryScope       = getenvDefault("GOPACKAGESDRIVER_BAZEL_QUERY_SCOPE", "")
	bazelBuildFlags       = strings.Fields(os.Getenv("GOPACKAGESDRIVER_BAZEL_BUILD_FLAGS"))
	workspaceRoot         = os.Getenv("BUILD_WORKSPACE_DIRECTORY")
	additionalAspects     = strings.Fields(os.Getenv("GOPACKAGESDRIVER_BAZEL_ADDTL_ASPECTS"))
	additionalKinds       = strings.Fields(os.Getenv("GOPACKAGESDRIVER_BAZEL_KINDS"))
	emptyResponse         = &driverResponse{
		NotHandled: true,
		Sizes:      types.SizesFor("gc", "amd64").(*types.StdSizes),
		Roots:      []string{},
		Packages:   []*FlatPackage{},
	}
)

func run() (*driverResponse, error) {
	ctx, cancel := signalContext(context.Background(), os.Interrupt)
	defer cancel()

	queries := os.Args[1:]

	request, err := ReadDriverRequest(os.Stdin)
	if err != nil {
		return emptyResponse, fmt.Errorf("unable to read request: %w", err)
	}

	bazel, err := NewBazel(ctx, bazelBin, workspaceRoot, bazelStartupFlags)
	if err != nil {
		return emptyResponse, fmt.Errorf("unable to create bazel instance: %w", err)
	}

	bazelJsonBuilder, err := NewBazelJSONBuilder(bazel, queries...)
	if err != nil {
		return emptyResponse, fmt.Errorf("unable to build JSON files: %w", err)
	}

	jsonFiles, err := bazelJsonBuilder.Build(ctx, request.Mode)
	if err != nil {
		return emptyResponse, fmt.Errorf("unable to build JSON files: %w", err)
	}

	driver, err := NewJSONPackagesDriver(jsonFiles, bazelJsonBuilder.PathResolver())
	if err != nil {
		return emptyResponse, fmt.Errorf("unable to load JSON files: %w", err)
	}

	return driver.Match(queries...), nil
}

func main() {
	response, err := run()
	if err := json.NewEncoder(os.Stdout).Encode(response); err != nil {
		fmt.Fprintf(os.Stderr, "unable to encode response: %v", err)
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v", err)
		// gopls will check the packages driver exit code, and if there is an
		// error, it will fall back to go list. Obviously we don't want that,
		// so force a 0 exit code.
		os.Exit(0)
	}
}
