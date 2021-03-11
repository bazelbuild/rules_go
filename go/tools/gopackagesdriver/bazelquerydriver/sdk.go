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

package bazelquerydriver

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/bazelbuild/bazel-watcher/bazel"
	"github.com/bazelbuild/rules_go/go/tools/gopackagesdriver/protocol"
	"golang.org/x/tools/go/packages"
)

type gosdk struct {
	goroot   string
	packages map[string]bool
}

func newGoSDK(bazel bazel.Bazel) (*gosdk, error) {
	info, err := bazel.Info()
	if err != nil {
		return nil, err
	}
	bazelBin := info["bazel-bin"]
	_, err = bazel.Build("@go_sdk//:package_list")
	if err != nil {
		return nil, err
	}

	root, err := findGoroot(bazel)
	if err != nil {
		return nil, err
	}

	s := &gosdk{
		goroot: root,
	}

	return s.readPackages(filepath.Join(bazelBin, "external/go_sdk/packages.txt"))
}

func (s *gosdk) readPackages(filename string) (*gosdk, error) {
	s.packages = make(map[string]bool)
	f, err := os.Open(filename)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		s.packages[scanner.Text()] = true
	}
	return s, scanner.Err()
}

func (s *gosdk) loadPackages(cfg *protocol.Request, pkgs map[string]bool) ([]*packages.Package, error) {
	words := make([]string, 0, len(pkgs))
	for pkg, included := range pkgs {
		if included {
			words = append(words, pkg)
		}
	}
	if len(words) == 0 {
		return nil, nil
	}

	sdkConfig := &packages.Config{
		Mode:       cfg.Mode,
		Env:        append(cfg.Env, fmt.Sprintf("GOROOT=%v", s.goroot), "GOPACKAGESDRIVER=off"),
		BuildFlags: cfg.BuildFlags,
		Tests:      cfg.Tests,
	}

	// Concurrent calls can result in "failed to cache compiled Go files" errors.
	// So retry if we get an error.
	// https://github.com/golang/go/issues/29667
	var err error
	var result []*packages.Package
	for i := 0; i < 5; i++ {
		if result, err = packages.Load(sdkConfig, words...); err == nil {
			return result, nil
		}
		time.Sleep(1 * time.Millisecond)
	}
	return nil, err
}

func findGoroot(bazel bazel.Bazel) (string, error) {
	results, err := bazel.Query("@go_sdk//:ROOT")
	if err != nil {
		return "", err
	}
	buildfile := results.Target[0].GetSourceFile().GetLocation()
	return filepath.Dir(buildfile), nil
}
