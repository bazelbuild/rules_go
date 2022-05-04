package main

import (
	"encoding/json"
	"fmt"
	"log"

	"github.com/bazelbuild/rules_go/go/analyzer/staticcheck/util"
)

type config struct {
	// onlyFiles is a list of regular expressions that match files an analyzer
	// will emit diagnostics for. When empty, the analyzer will emit diagnostics
	// for all files.
	OnlyFiles map[string]string `json:"only_files,omitempty"`

	// excludeFiles is a list of regular expressions that match files that an
	// analyzer will not emit diagnostics for.
	ExcludeFiles map[string]string `json:"exclude_files,omitempty"`
}

func main() {
	configs := make(map[string]*config, len(util.Analyzers))
	defaultConfig := &config{
		ExcludeFiles: map[string]string{"external/": "third_party"},
	}

	for a := range util.Analyzers {
		configs[a] = defaultConfig
	}

	b, err := json.MarshalIndent(configs, "", "  ")
	if err != nil {
		log.Fatalf("json marshal failed: %v", err)
	}

	fmt.Println(string(b))
}
