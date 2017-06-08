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

import (
	"fmt"
	"go/build"
	"sort"
	"strings"
)

// PlatformConstraints is a map from config_setting labels (for example,
// "@io_bazel_rules_go//go/platform:linux_amd64") to a sets of build tags
// that are true on each platform (for example, "linux,amd64").
type PlatformConstraints map[string]map[string]bool

// DefaultPlatformConstraints is the default set of platforms that Gazelle
// will generate files for. These are the platforms that both Go and Bazel
// support.
var DefaultPlatformConstraints PlatformConstraints

func init() {
	DefaultPlatformConstraints = make(PlatformConstraints)
	arch := "amd64"
	for _, os := range []string{"darwin", "linux", "windows"} {
		label := fmt.Sprintf("@io_bazel_rules_go//go/platform:%s_%s", os, arch)
		DefaultPlatformConstraints[label] = map[string]bool{arch: true, os: true}
	}
}

// PreprocessTags performs some automatic processing on generic and
// platform-specific tags before they are used to match files.
func PreprocessTags(genericTags map[string]bool, platforms PlatformConstraints) {
	genericTags["cgo"] = true
	genericTags["gc"] = true
	for _, t := range build.Default.ReleaseTags {
		genericTags[t] = true
	}
	for _, platformTags := range platforms {
		for t, _ := range genericTags {
			platformTags[t] = true
		}
	}
}

// Package contains metadata about a Go package extracted from a directory.
// It fills a similar role to go/build.Package, but it separates files by
// target instead of by type, and it supports multiple platforms.
type Package struct {
	Dir  string
	Name string

	Library, CgoLibrary, Binary, Test, XTest Target

	Protos  []string
	HasPbGo bool
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

// addFile adds the file described by "info" to a target in the package "p" if
// the file is buildable.
//
// "cgo" tells whether a ".go" file in the package contains cgo code. This
// affects whether C files are added to targets.
// "buildTags" is a set of tags that are true on all platforms.
// "platforms" is a map from platform names (labels referencing config_settings)
// to sets of tags that are true on those platforms. The tag sets may include
// "buildTags".
//
// An error is returned if a file is buildable but invalid (for example, a
// test .go file containing cgo code). Files that are not buildable will not
// be added to any target (for example, .txt files).
func (p *Package) addFile(info fileInfo, cgo bool, buildTags map[string]bool, platforms PlatformConstraints) error {
	switch {
	case info.isXTest:
		if info.isCgo {
			return fmt.Errorf("%s: use of cgo in test not supported", info.path)
		}
		p.XTest.addFile(info, buildTags, platforms)
	case info.isTest:
		if info.isCgo {
			return fmt.Errorf("%s: use of cgo in test not supported", info.path)
		}
		p.Test.addFile(info, buildTags, platforms)
	case info.isCgo || cgo && (info.category == cExt || info.category == hExt || info.category == csExt):
		p.CgoLibrary.addFile(info, buildTags, platforms)
	case info.category == goExt || info.category == sExt || info.category == hExt:
		p.Library.addFile(info, buildTags, platforms)
	case info.category == protoExt:
		p.Protos = append(p.Protos, info.name)
	}

	if strings.HasSuffix(info.name, ".pb.go") {
		p.HasPbGo = true
	}

	return nil
}

func (t *Target) addFile(info fileInfo, buildTags map[string]bool, platforms PlatformConstraints) {
	if !info.hasConstraints() || info.checkConstraints(buildTags) {
		t.Sources.addGenericStrings(info.name)
		t.Imports.addGenericStrings(info.imports...)
		t.COpts.addGenericOpts(platforms, info.copts)
		t.CLinkOpts.addGenericOpts(platforms, info.clinkopts)
		return
	}

	for name, tags := range platforms {
		if info.checkConstraints(tags) {
			t.Sources.addPlatformStrings(name, info.name)
			t.Imports.addPlatformStrings(name, info.imports...)
			t.COpts.addTaggedOpts(name, info.copts, tags)
			t.CLinkOpts.addTaggedOpts(name, info.clinkopts, tags)
		}
	}
}

func (ps *PlatformStrings) addGenericStrings(ss ...string) {
	ps.Generic = append(ps.Generic, ss...)
}

func (ps *PlatformStrings) addGenericOpts(platforms PlatformConstraints, opts []taggedOpts) {
	for _, t := range opts {
		if t.tags == "" {
			ps.Generic = append(ps.Generic, t.opts...)
			continue
		}

		for name, tags := range platforms {
			if checkTags(t.tags, tags) {
				if ps.Platform == nil {
					ps.Platform = make(map[string][]string)
				}
				ps.Platform[name] = append(ps.Platform[name], t.opts...)
			}
		}
	}
}

func (ps *PlatformStrings) addPlatformStrings(name string, ss ...string) {
	if ps.Platform == nil {
		ps.Platform = make(map[string][]string)
	}
	ps.Platform[name] = append(ps.Platform[name], ss...)
}

func (ps *PlatformStrings) addTaggedOpts(name string, opts []taggedOpts, tags map[string]bool) {
	for _, t := range opts {
		if t.tags == "" || checkTags(t.tags, tags) {
			if ps.Platform == nil {
				ps.Platform = make(map[string][]string)
			}
			ps.Platform[name] = append(ps.Platform[name], t.opts...)
		}
	}
}

// Clean sorts and de-duplicates PlatformStrings. It also removes any
// strings from platform-specific lists that also appear in the generic list.
// This is useful for imports.
func (ps *PlatformStrings) Clean() {
	sort.Strings(ps.Generic)
	ps.Generic = uniq(ps.Generic)

	genSet := make(map[string]bool)
	for _, s := range ps.Generic {
		genSet[s] = true
	}

	if ps.Platform == nil {
		return
	}

	for n, ss := range ps.Platform {
		ss = remove(ss, genSet)
		if len(ss) == 0 {
			delete(ps.Platform, n)
			continue
		}
		sort.Strings(ss)
		ps.Platform[n] = uniq(ss)
	}
	if len(ps.Platform) == 0 {
		ps.Platform = nil
	}
}

func remove(ss []string, remove map[string]bool) []string {
	var r, w int
	for r, w = 0, 0; r < len(ss); r++ {
		if !remove[ss[r]] {
			ss[w] = ss[r]
			w++
		}
	}
	return ss[:w]
}

func uniq(ss []string) []string {
	if len(ss) <= 1 {
		return ss
	}
	result := ss[:1]
	prev := ss[0]
	for _, s := range ss[1:] {
		if s != prev {
			result = append(result, s)
			prev = s
		}
	}
	return result
}

// Map applies a function to the strings in "ps" and returns a new
// PlatformStrings with the results. This is useful for converting import
// paths to labels.
func (ps *PlatformStrings) Map(f func(string) (string, error)) (PlatformStrings, []error) {
	result := PlatformStrings{Generic: make([]string, 0, len(ps.Generic))}
	var errors []error
	for _, s := range ps.Generic {
		if r, err := f(s); err != nil {
			errors = append(errors, err)
		} else {
			result.Generic = append(result.Generic, r)
		}
	}

	if ps.Platform != nil {
		result.Platform = make(map[string][]string)
		for n, ss := range ps.Platform {
			result.Platform[n] = make([]string, 0, len(ss))
			for _, s := range ss {
				if r, err := f(s); err != nil {
					errors = append(errors, err)
				} else {
					result.Platform[n] = append(result.Platform[n], r)
				}
			}
		}
	}

	return result, errors
}
