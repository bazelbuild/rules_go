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

package packages

import "strings"

// Package contains metadata about a Go package extracted from a directory.
// It fills a similar role to go/build.Package, but it separates files by
// target instead of by type, and it supports multiple platforms.
type Package struct {
	Dir  string
	Name string

	Library, CgoLibrary, Binary, Test, XTest Target
}

// Target contains metadata about a buildable Go target in a package.
type Target struct {
	Sources, Imports PlatformStrings
	COpts, CLinkOpts PlatformStrings
}

// PlatformStrings contains a set of strings associated with a buildable
// Go target in a package. This is used to store source file names,
// import paths, and flags.
type PlatformStrings struct {
	// Generic is a list of strings not specific to any platform.
	Generic []string

	// Platform is a map of lists of platform-specific strings. The map is keyed
	// by the name of the platform.
	Platform map[string][]string
}

// IsCommand returns true if the package name is "main".
func (p *Package) IsCommand() bool {
	return p.Name == "main"
}

// HasGo returns true if at least one target in the package contains a
// .go source file. If a package does not contain Go code, Gazelle will
// not generate rules for it.
func (p *Package) HasGo() bool {
	return p.Library.HasGo() || p.CgoLibrary.HasGo() || p.Binary.HasGo() || p.Test.HasGo() || p.XTest.HasGo()
}

// firstGoFile returns the name of a .go file if the package contains at least
// one .go file, or "" otherwise. Used by HasGo and for error reporting.
func (p *Package) firstGoFile() string {
	if f := p.Library.firstGoFile(); f != "" {
		return f
	}
	if f := p.CgoLibrary.firstGoFile(); f != "" {
		return f
	}
	if f := p.Binary.firstGoFile(); f != "" {
		return f
	}
	if f := p.Test.firstGoFile(); f != "" {
		return f
	}
	return p.XTest.firstGoFile()
}

func (t *Target) HasGo() bool {
	return t.Sources.HasGo()
}

func (t *Target) firstGoFile() string {
	return t.Sources.firstGoFile()
}

func (ts *PlatformStrings) HasGo() bool {
	return ts.firstGoFile() != ""
}

func (ts *PlatformStrings) IsEmpty() bool {
	if len(ts.Generic) > 0 {
		return false
	}
	for _, s := range ts.Platform {
		if len(s) > 0 {
			return false
		}
	}
	return true
}

func (ts *PlatformStrings) firstGoFile() string {
	for _, f := range ts.Generic {
		if strings.HasSuffix(f, ".go") {
			return f
		}
	}
	for _, fs := range ts.Platform {
		for _, f := range fs {
			if strings.HasSuffix(f, ".go") {
				return f
			}
		}
	}
	return ""
}
