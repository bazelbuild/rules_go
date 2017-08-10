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

package resolve

import (
	"fmt"
	"path"
	"strings"

	"github.com/bazelbuild/rules_go/go/tools/gazelle/config"
)

// A Resolver resolves a Go importpath into a label in Bazel.
type Resolver interface {
	// Resolve resolves a Go importpath "importpath" into a Label. "importpath"
	// must not be relative. The returned Label will never be relative.
	Resolve(importpath string) (Label, error)
}

// A Label represents a label of a build target in Bazel.
type Label struct {
	Repo, Pkg, Name string
	Relative        bool
}

func (l Label) String() string {
	if l.Relative {
		return fmt.Sprintf(":%s", l.Name)
	}

	var repo string
	if l.Repo != "" {
		repo = fmt.Sprintf("@%s", l.Repo)
	}

	if path.Base(l.Pkg) == l.Name {
		return fmt.Sprintf("%s//%s", repo, l.Pkg)
	}
	return fmt.Sprintf("%s//%s:%s", repo, l.Pkg, l.Name)
}

func NewResolver(c *config.Config, l Labeler) Resolver {
	var e Resolver
	switch c.DepMode {
	case config.ExternalMode:
		e = newExternalResolver(l, c.KnownImports)
	case config.VendorMode:
		e = newVendoredResolver(l)
	}

	return &unifiedResolver{
		goPrefix: c.GoPrefix,
		local:    &structuredResolver{l: l, goPrefix: c.GoPrefix},
		external: e,
	}
}

type unifiedResolver struct {
	goPrefix        string
	local, external Resolver
}

func (r *unifiedResolver) Resolve(importpath string) (Label, error) {
	if importpath != r.goPrefix && !strings.HasPrefix(importpath, r.goPrefix+"/") {
		return r.external.Resolve(importpath)
	}
	return r.local.Resolve(importpath)
}
