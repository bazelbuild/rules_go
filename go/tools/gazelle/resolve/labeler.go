/* Copyright 2017 The Bazel Authors. All rights reserved.

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
	"path"
	"path/filepath"

	"github.com/bazelbuild/rules_go/go/tools/gazelle/config"
)

// Labeler generates Bazel labels for rules, based on their locations
// within the repository.
type Labeler struct {
	c *config.Config
}

func NewLabeler(c *config.Config) *Labeler {
	return &Labeler{c}
}

func (l *Labeler) LibraryLabel(rel string) Label {
	return Label{Pkg: rel, Name: config.DefaultLibName}
}

func (l *Labeler) TestLabel(rel string, isXTest bool) Label {
	var name string
	if isXTest {
		name = config.DefaultXTestName
	} else {
		name = config.DefaultTestName
	}
	return Label{Pkg: rel, Name: name}
}

func (l *Labeler) BinaryLabel(rel string) Label {
	name := relBaseName(l.c, rel)
	return Label{Pkg: rel, Name: name}
}

func (l *Labeler) ProtoLabel(rel, name string) Label {
	return Label{Pkg: rel, Name: name + "_proto"}
}

func (l *Labeler) GoProtoLabel(rel, name string) Label {
	return Label{Pkg: rel, Name: name + "_go_proto"}
}

func relBaseName(c *config.Config, rel string) string {
	base := path.Base(rel)
	if base == "." || base == "/" {
		base = path.Base(c.GoPrefix)
	}
	if base == "." || base == "/" {
		base = filepath.Base(c.RepoRoot)
	}
	if base == "." || base == "/" {
		base = "root"
	}
	return base
}
