// Copyright 2021 The Bazel Go Rules Authors. All rights reserved.
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

package pkgconv

import (
	"fmt"
	"log"
	"path/filepath"
	"strings"

	"github.com/bazelbuild/bazel-watcher/third_party/bazel/master/src/main/protobuf/blaze_query"
	"golang.org/x/tools/go/packages"
)

type target struct {
	name       string
	folder     string
	srcs       []string
	deps       []string
	importpath string
	rule       string
	embed      []string
	suffix     string
	compilers  []string
	actual     string
}

// Load generates packages.Packages from bazel query results.
// Each go rule in the input is converted into a Package with ID, PkgPath, and Imports.
// Imports is generated from bazel deps, so it does not include any standard library packages.
// Name may also be set for test packages.
func Load(protoTargets []*blaze_query.Target) []*packages.Package {
	var pkgs []*packages.Package

	targets := make(map[string]*target)

	for _, pt := range protoTargets {
		if pt.GetType() != blaze_query.Target_RULE {
			continue
		}
		rule := pt.GetRule()
		t := &target{
			name:   rule.GetName(),
			rule:   rule.GetRuleClass(),
			folder: filepath.Dir(rule.GetLocation()),
		}
		for _, a := range rule.GetAttribute() {
			switch a.GetName() {
			case "deps":
				t.deps = a.GetStringListValue()
			case "srcs":
				t.srcs = a.GetStringListValue()
			case "embed":
				t.embed = a.GetStringListValue()
			case "importpath":
				t.importpath = a.GetStringValue()
			case "suffix":
				t.suffix = a.GetStringValue()
			case "proto":
				proto := a.GetStringValue()
				if proto != "" {
					t.srcs = append(t.srcs, proto)
				}
			case "protos":
				t.srcs = append(t.srcs, a.GetStringListValue()...)
			case "compilers":
				t.compilers = a.GetStringListValue()
			case "actual":
				t.actual = a.GetStringValue()
			case "library":
				t.embed = []string{a.GetStringValue()}
			}
		}
		targets[t.name] = t
	}

	for _, t := range targets {
		pkg := t.toPackage(targets)
		pkgs = append(pkgs, pkg...)
	}

	return pkgs
}

func (t target) toPackage(targets map[string]*target) []*packages.Package {
	switch t.rule {
	case "go_library":
		return convertGoLibrary(t, targets)
	case "go_proto_library":
		return convertGoProtoLibrary(t, targets)
	case "go_tool_library":
		// ignore
	case "go_test":
		return convertGoTest(t, targets)
	case "alias":
		actual := targets[t.actual]
		if actual != nil {
			return actual.toPackage(targets)
		}
	default:
		if t.importpath != "" {
			log.Printf("importpath %#v for %v %v", t.importpath, t.rule, t.name)
		}
	}
	return nil
}

func binpath(pkg string) string {
	if index := strings.Index(pkg, ":"); index != -1 {
		pkg = pkg[:index]
	}
	if pkg[0] == '@' {
		parts := strings.Split(pkg[1:], "//")
		return filepath.Join("bazel-bin", "external", parts[0], parts[1])
	}
	pkg = strings.TrimPrefix(pkg, "//")
	return filepath.Join("bazel-bin", pkg)
}

func targetName(t *blaze_query.Target) string {
	switch t.GetType() {
	case blaze_query.Target_RULE:
		return t.GetRule().GetName()
	case blaze_query.Target_SOURCE_FILE:
		return t.GetSourceFile().GetName()
	case blaze_query.Target_GENERATED_FILE:
		return t.GetGeneratedFile().GetName()
	case blaze_query.Target_PACKAGE_GROUP:
		return t.GetPackageGroup().GetName()
	case blaze_query.Target_ENVIRONMENT_GROUP:
		return t.GetEnvironmentGroup().GetName()
	}
	return fmt.Sprintf("%#v", t)
}
