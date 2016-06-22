/* Copyright 2016 The Bazel Authors. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package rules

import (
	"go/build"
	"path"

	bzl "github.com/bazelbuild/buildifier/core"
)

// Generator generates Bazel build rules for Go build targets
type Generator interface {
	// Generate generates build rules for build targets in a Go package in a
	// repository.
	//
	// "rel" is a relative slash-separated path from the repostiry root
	// directory to the Go package directory. It is empty if the package
	// directory is the repository root itself.
	// "pkg" is a description about the package.
	Generate(rel string, pkg *build.Package) ([]*bzl.Rule, error)
}

// NewGenerator returns an implementation of Generator.
func NewGenerator() Generator {
	return new(generator)
}

type generator struct{}

func (g *generator) Generate(rel string, pkg *build.Package) ([]*bzl.Rule, error) {
	kind := "go_library"
	name := "go_default_library"
	if pkg.IsCommand() {
		kind = "go_binary"
		name = path.Base(pkg.Dir)
	}

	var rules []*bzl.Rule
	r, err := newRule(kind, nil, []keyvalue{
		{key: "name", value: name},
		{key: "srcs", value: pkg.GoFiles},
	})
	if err != nil {
		return nil, err
	}
	rules = append(rules, r)
	return rules, nil
}
