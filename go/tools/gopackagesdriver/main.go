package main

import (
	"context"
	"encoding/json"
	"fmt"
	"go/types"
	"os"
	"os/signal"
	"strings"
)

type driverResponse struct {
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
	bazelBin          = getenvDefault("GOPACKAGESDRIVER_BAZEL", "bazel")
	workspaceRoot     = os.Getenv("BUILD_WORKSPACE_DIRECTORY")
	targetsStr        = os.Getenv("GOPACKAGESDRIVER_BAZEL_TARGETS")
	targetsQueryStr   = os.Getenv("GOPACKAGESDRIVER_BAZEL_QUERY")
	targetsTagFilters = os.Getenv("GOPACKAGESDRIVER_BAZEL_TAG_FILTERS")
)

func getenvDefault(key, defaultValue string) string {
	if v, ok := os.LookupEnv(key); ok {
		return v
	}
	return defaultValue
}

func signalContext(parentCtx context.Context, signals ...os.Signal) (ctx context.Context, stop context.CancelFunc) {
	ctx, cancel := context.WithCancel(parentCtx)
	ch := make(chan os.Signal, 1)
	go func() {
		select {
		case <-ch:
			cancel()
		case <-ctx.Done():
		}
	}()
	signal.Notify(ch, signals...)

	return ctx, cancel
}

func run() error {
	ctx, cancel := signalContext(context.Background(), os.Interrupt)
	defer cancel()

	request, err := ReadDriverRequest(os.Stdin)
	if err != nil {
		return fmt.Errorf("unable to read request: %w", err)
	}

	bazel, err := NewBazel(ctx, bazelBin, workspaceRoot)
	if err != nil {
		return fmt.Errorf("unable to create bazel instance: %w", err)
	}

	targets := []string{}
	if targetsStr != "" {
		targets = strings.Split(targetsStr, " ")
	}
	bazelJsonBuilder, err := NewBazelJSONBuilder(bazel, targetsQueryStr, targetsTagFilters, targets)
	if err != nil {
		return fmt.Errorf("unable to build JSON files: %w", err)
	}

	jsonFiles, err := bazelJsonBuilder.Build(ctx, request.Mode)
	if err != nil {
		return fmt.Errorf("unable to build JSON files: %w", err)
	}

	driver, err := NewJSONPackagesDriver(jsonFiles, bazelJsonBuilder.PathResolver())
	if err != nil {
		return fmt.Errorf("unable to load JSON files: %w", err)
	}

	pkgs := driver.Packages()
	roots := []string{}
	for _, pkg := range pkgs {
		if pkg.IsRoot() {
			roots = append(roots, pkg.ID)
		}
	}

	response := &driverResponse{
		NotHandled: false,
		Sizes:      types.SizesFor("gc", "amd64").(*types.StdSizes),
		Roots:      roots,
		Packages:   pkgs,
	}
	if err := json.NewEncoder(os.Stdout).Encode(response); err != nil {
		return fmt.Errorf("unable to encode response: %w", err)
	}

	return nil
}

func main() {
	if err := run(); err != nil {
		panic(err)
	}
}
