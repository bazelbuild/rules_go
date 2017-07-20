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

const (
	// defaultLibName is the name of the default go_library rule in a Go
	// package directory. It must be consistent to DEFAULT_LIB in go/private/common.bf.
	DefaultLibName = "go_default_library"
	// defaultTestName is a name of an internal test corresponding to
	// defaultLibName. It does not need to be consistent to something but it
	// just needs to be unique in the Bazel package
	DefaultTestName = "go_default_test"
	// defaultXTestName is a name of an external test corresponding to
	// defaultLibName.
	DefaultXTestName = "go_default_xtest"
	// defaultProtosName is the name of a filegroup created
	// whenever the library contains .pb.go files
	DefaultProtosName = "go_default_library_protos"
	// defaultCgoLibName is the name of the default cgo_library rule in a Go package directory.
	DefaultCgoLibName = "cgo_default_library"
)

// A LabelResolver resolves a Go importpath into a label in Bazel.
type LabelResolver interface {
	// Resolve resolves a Go importpath "importpath", which is referenced from
	// a Go package directory "dir" in the current repository.
	// "dir" is a relative slash-delimited path from the top level of the
	// current repository.
	Resolve(importpath, dir string) (Label, error)
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

func (r *unifiedResolver) Resolve(importpath, dir string) (Label, error) {
	if importpath != r.goPrefix && !strings.HasPrefix(importpath, r.goPrefix+"/") && !isRelative(importpath) {
		return r.external.Resolve(importpath, dir)
	}
	return r.local.Resolve(importpath, dir)
}

// isRelative determines if an importpath is relative.
func isRelative(importpath string) bool {
	return strings.HasPrefix(importpath, "./") || strings.HasPrefix(importpath, "..")
}
