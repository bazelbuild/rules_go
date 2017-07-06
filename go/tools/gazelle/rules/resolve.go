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
	"fmt"
	"path"
	"strings"

	"github.com/bazelbuild/rules_go/go/tools/gazelle/config"
)

// TODO(jayconrod): move LabelResolver into a new package.

// A LabelResolver resolves a Go importpath into a label in Bazel.
type LabelResolver interface {
	// resolve resolves a Go importpath "importpath", which is referenced from
	// a Go package directory "dir" in the current repository.
	// "dir" is a relative slash-delimited path from the top level of the
	// current repository.
	resolve(importpath, dir string) (label, error)
}

// A label represents a label of a build target in Bazel.
type label struct {
	repo, pkg, name string
	relative        bool
}

func (l label) String() string {
	if l.relative {
		return fmt.Sprintf(":%s", l.name)
	}

	var repo string
	if l.repo != "" {
		repo = fmt.Sprintf("@%s", l.repo)
	}

	if path.Base(l.pkg) == l.name {
		return fmt.Sprintf("%s//%s", repo, l.pkg)
	}
	return fmt.Sprintf("%s//%s:%s", repo, l.pkg, l.name)
}

func NewLabelResolver(c *config.Config) LabelResolver {
	var e LabelResolver
	switch c.DepMode {
	case config.ExternalMode:
		e = newExternalResolver()
	case config.VendorMode:
		e = vendoredResolver{}
	}

	return &unifiedResolver{
		goPrefix: c.GoPrefix,
		local:    structuredResolver{c.GoPrefix},
		external: e,
	}
}

type unifiedResolver struct {
	goPrefix        string
	local, external LabelResolver
}

func (r *unifiedResolver) resolve(importpath, dir string) (label, error) {
	if importpath != r.goPrefix && !strings.HasPrefix(importpath, r.goPrefix+"/") && !isRelative(importpath) {
		return r.external.resolve(importpath, dir)
	}
	return r.local.resolve(importpath, dir)
}

// isRelative determines if an importpath is relative.
func isRelative(importpath string) bool {
	return strings.HasPrefix(importpath, "./") || strings.HasPrefix(importpath, "..")
}
