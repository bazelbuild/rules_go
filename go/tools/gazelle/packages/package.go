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
	"errors"
	"fmt"
	"path"
	"sort"
	"strings"

	"github.com/bazelbuild/rules_go/go/tools/gazelle/config"
)

// Package contains metadata about a Go package extracted from a directory.
// It fills a similar role to go/build.Package, but it separates files by
// target instead of by type, and it supports multiple platforms.
type Package struct {
	// Name is the symbol found in package declarations of the .go files in
	// the package. It does not include the "_test" suffix from external tests.
	Name string

	// Dir is an absolute path to the directory that contains the package.
	Dir string

	// Rel is the relative path to the package directory from the repository
	// root. If the directory is the repository root itself, Rel is empty.
	// Components in Rel are separated with slashes.
	Rel string

	Library, Binary, Test, XTest GoTarget
	Proto                        ProtoTarget

	HasTestdata bool
}

// GoTarget contains metadata about a buildable Go target in a package.
type GoTarget struct {
	Sources, Imports PlatformStrings
	COpts, CLinkOpts PlatformStrings
	Cgo              bool
}

// ProtoTarget contains metadata about proto files in a package.
type ProtoTarget struct {
	Sources, Imports PlatformStrings
	HasServices      bool

	// HasPbGo indicates whether unexcluded .pb.go files are present in the
	// same package. They will not be in this target's sources.
	HasPbGo bool
}

// PlatformStrings contains a set of strings associated with a buildable
// Go target in a package. This is used to store source file names,
// import paths, and flags.
type PlatformStrings struct {
	// Generic is a list of strings not specific to any platform.
	Generic []string

	// OS is a map from OS name (anything in config.KnownOSs) to
	// OS-specific strings.
	OS map[string][]string

	// Arch is a map from architecture name (anything in config.KnownArchs) to
	// architecture-specific strings.
	Arch map[string][]string

	// Platform is a map from platforms to OS and architecture-specific strings.
	Platform map[config.Platform][]string
}

// IsCommand returns true if the package name is "main".
func (p *Package) IsCommand() bool {
	return p.Name == "main"
}

// isBuildable returns true if anything in the package is buildable.
// This is true if the package has Go code that satisfies build constraints
// on any platform or has proto files not in legacy mode.
func (p *Package) isBuildable(c *config.Config) bool {
	return p.Library.HasGo() || p.Binary.HasGo() || p.Test.HasGo() || p.XTest.HasGo() ||
		p.Proto.HasProto() && c.ProtoMode == config.DefaultProtoMode
}

// ImportPath returns the inferred Go import path for this package.
// TODO(jayconrod): extract canonical import paths from comments on
// package statements.
func (p *Package) ImportPath(c *config.Config) string {
	if p.Rel == c.GoPrefixRel {
		return c.GoPrefix
	} else {
		fromPrefixRel := strings.TrimPrefix(p.Rel, c.GoPrefixRel+"/")
		return path.Join(c.GoPrefix, fromPrefixRel)
	}
}

// firstGoFile returns the name of a .go file if the package contains at least
// one .go file, or "" otherwise. Used by HasGo and for error reporting.
func (p *Package) firstGoFile() string {
	if f := p.Library.firstGoFile(); f != "" {
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

func (t *GoTarget) HasGo() bool {
	return t.Sources.HasGo()
}

func (t *GoTarget) firstGoFile() string {
	return t.Sources.firstGoFile()
}

func (t *ProtoTarget) HasProto() bool {
	return !t.Sources.IsEmpty()
}

func (ps *PlatformStrings) HasGo() bool {
	return ps.firstGoFile() != ""
}

func (ps *PlatformStrings) IsEmpty() bool {
	return len(ps.Generic) == 0 && len(ps.OS) == 0 && len(ps.Arch) == 0 && len(ps.Platform) == 0
}

func (ps *PlatformStrings) firstGoFile() string {
	for _, f := range ps.Generic {
		if strings.HasSuffix(f, ".go") {
			return f
		}
	}
	for _, fs := range ps.OS {
		for _, f := range fs {
			if strings.HasSuffix(f, ".go") {
				return f
			}
		}
	}
	for _, fs := range ps.Arch {
		for _, f := range fs {
			if strings.HasSuffix(f, ".go") {
				return f
			}
		}
	}
	for _, fs := range ps.Platform {
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
//
// An error is returned if a file is buildable but invalid (for example, a
// test .go file containing cgo code). Files that are not buildable will not
// be added to any target (for example, .txt files).
func (p *Package) addFile(c *config.Config, info fileInfo, cgo bool) error {
	switch {
	case info.category == ignoredExt || info.category == unsupportedExt ||
		!cgo && (info.category == cExt || info.category == csExt) ||
		c.ProtoMode == config.DisableProtoMode && info.category == protoExt:
		return nil
	case info.isXTest:
		if info.isCgo {
			return fmt.Errorf("%s: use of cgo in test not supported", info.path)
		}
		p.XTest.addFile(c, info)
	case info.isTest:
		if info.isCgo {
			return fmt.Errorf("%s: use of cgo in test not supported", info.path)
		}
		p.Test.addFile(c, info)
	case info.category == protoExt:
		p.Proto.addFile(c, info)
	default:
		p.Library.addFile(c, info)
	}
	if strings.HasSuffix(info.name, ".pb.go") {
		p.Proto.HasPbGo = true
	}

	return nil
}

func (t *GoTarget) addFile(c *config.Config, info fileInfo) {
	if info.isCgo {
		t.Cgo = true
	}
	add := getPlatformStringsAddFunction(c, info, nil)
	add(&t.Sources, info.name)
	add(&t.Imports, info.imports...)
	for _, copts := range info.copts {
		optAdd := add
		if len(copts.tags) > 0 {
			optAdd = getPlatformStringsAddFunction(c, info, copts.tags)
		}
		optAdd(&t.COpts, copts.opts...)
		optAdd(&t.COpts, optSeparator)
	}
	for _, clinkopts := range info.clinkopts {
		optAdd := add
		if len(clinkopts.tags) > 0 {
			optAdd = getPlatformStringsAddFunction(c, info, clinkopts.tags)
		}
		optAdd(&t.CLinkOpts, clinkopts.opts...)
		optAdd(&t.CLinkOpts, optSeparator)
	}
}

func (t *ProtoTarget) addFile(c *config.Config, info fileInfo) {
	add := getPlatformStringsAddFunction(c, info, nil)
	add(&t.Sources, info.name)
	add(&t.Imports, info.imports...)
	t.HasServices = t.HasServices || info.hasServices
}

func (ps *PlatformStrings) addStrings(c *config.Config, info fileInfo, cgoTags tagLine, ss ...string) {
	add := getPlatformStringsAddFunction(c, info, cgoTags)
	add(ps, ss...)
}

// getPlatformStringsAddFunction returns a function used to add strings to
// a PlatformStrings object under the same set of constraints. This is a
// performance optimization to avoid evaluating constraints repeatedly.
func getPlatformStringsAddFunction(c *config.Config, info fileInfo, cgoTags tagLine) func(ps *PlatformStrings, ss ...string) {
	isOSSpecific, isArchSpecific := isOSArchSpecific(info, cgoTags)

	switch {
	case !isOSSpecific && !isArchSpecific:
		if checkConstraints(c, "", "", info.goos, info.goarch, info.tags, cgoTags) {
			return func(ps *PlatformStrings, ss ...string) {
				ps.Generic = append(ps.Generic, ss...)
			}
		}

	case isOSSpecific && !isArchSpecific:
		var osMatch []string
		for _, os := range config.KnownOSs {
			if checkConstraints(c, os, "", info.goos, info.goarch, info.tags, cgoTags) {
				osMatch = append(osMatch, os)
			}
		}
		if len(osMatch) > 0 {
			return func(ps *PlatformStrings, ss ...string) {
				if ps.OS == nil {
					ps.OS = make(map[string][]string)
				}
				for _, os := range osMatch {
					ps.OS[os] = append(ps.OS[os], ss...)
				}
			}
		}

	case !isOSSpecific && isArchSpecific:
		var archMatch []string
		for _, arch := range config.KnownArchs {
			if checkConstraints(c, "", arch, info.goos, info.goarch, info.tags, cgoTags) {
				archMatch = append(archMatch, arch)
			}
		}
		if len(archMatch) > 0 {
			return func(ps *PlatformStrings, ss ...string) {
				if ps.Arch == nil {
					ps.Arch = make(map[string][]string)
				}
				for _, arch := range archMatch {
					ps.Arch[arch] = append(ps.Arch[arch], ss...)
				}
			}
		}

	default:
		var platformMatch []config.Platform
		for _, platform := range config.KnownPlatforms {
			if checkConstraints(c, platform.OS, platform.Arch, info.goos, info.goarch, info.tags, cgoTags) {
				platformMatch = append(platformMatch, platform)
			}
		}
		if len(platformMatch) > 0 {
			return func(ps *PlatformStrings, ss ...string) {
				if ps.Platform == nil {
					ps.Platform = make(map[config.Platform][]string)
				}
				for _, platform := range platformMatch {
					ps.Platform[platform] = append(ps.Platform[platform], ss...)
				}
			}
		}
	}

	return func(_ *PlatformStrings, _ ...string) {}
}

// Clean sorts and de-duplicates PlatformStrings. It also removes any
// strings from platform-specific lists that also appear in the generic list.
// This is useful for imports.
func (ps *PlatformStrings) Clean() {
	genSet := make(map[string]bool)
	osArchSet := make(map[string]map[string]bool)

	sort.Strings(ps.Generic)
	ps.Generic = uniq(ps.Generic)
	for _, s := range ps.Generic {
		genSet[s] = true
	}

	if ps.OS != nil {
		for os, ss := range ps.OS {
			ss = remove(ss, genSet)
			if len(ss) == 0 {
				delete(ps.OS, os)
				continue
			}
			sort.Strings(ss)
			ss = uniq(ss)
			ps.OS[os] = ss
			osArchSet[os] = make(map[string]bool)
			for _, s := range ss {
				osArchSet[os][s] = true
			}
		}
		if len(ps.OS) == 0 {
			ps.OS = nil
		}
	}

	if ps.Arch != nil {
		for arch, ss := range ps.Arch {
			ss = remove(ss, genSet)
			if len(ss) == 0 {
				delete(ps.Arch, arch)
				continue
			}
			sort.Strings(ss)
			ss = uniq(ss)
			ps.Arch[arch] = ss
			osArchSet[arch] = make(map[string]bool)
			for _, s := range ss {
				osArchSet[arch][s] = true
			}
		}
		if len(ps.Arch) == 0 {
			ps.Arch = nil
		}
	}

	if ps.Platform != nil {
		for platform, ss := range ps.Platform {
			ss = remove(ss, genSet)
			if osSet, ok := osArchSet[platform.OS]; ok {
				ss = remove(ss, osSet)
			}
			if archSet, ok := osArchSet[platform.Arch]; ok {
				ss = remove(ss, archSet)
			}
			if len(ss) == 0 {
				delete(ps.Platform, platform)
				continue
			}
			sort.Strings(ss)
			ss = uniq(ss)
			ps.Platform[platform] = ss
		}
		if len(ps.Platform) == 0 {
			ps.Platform = nil
		}
	}
}

func remove(ss []string, removeSet map[string]bool) []string {
	var r, w int
	for r, w = 0, 0; r < len(ss); r++ {
		if !removeSet[ss[r]] {
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

var Skip = errors.New("Skip")

// Map applies a function f to the individual strings in ps. Map returns a
// new PlatformStrings with the results and a slice of errors that f returned.
// When f returns the error Skip, neither the result nor the error are recorded.
func (ps *PlatformStrings) Map(f func(string) (string, error)) (PlatformStrings, []error) {
	var errors []error

	mapSlice := func(ss []string) []string {
		rs := make([]string, 0, len(ss))
		for _, s := range ss {
			if r, err := f(s); err != nil {
				if err != Skip {
					errors = append(errors, err)
				}
			} else {
				rs = append(rs, r)
			}
		}
		return rs
	}

	mapStringMap := func(m map[string][]string) map[string][]string {
		if m == nil {
			return nil
		}
		rm := make(map[string][]string)
		for k, ss := range m {
			ss = mapSlice(ss)
			if len(ss) > 0 {
				rm[k] = ss
			}
		}
		if len(rm) == 0 {
			return nil
		}
		return rm
	}

	mapPlatformMap := func(m map[config.Platform][]string) map[config.Platform][]string {
		if m == nil {
			return nil
		}
		rm := make(map[config.Platform][]string)
		for k, ss := range m {
			ss = mapSlice(ss)
			if len(ss) > 0 {
				rm[k] = ss
			}
		}
		if len(rm) == 0 {
			return nil
		}
		return rm
	}

	result := PlatformStrings{
		Generic:  mapSlice(ps.Generic),
		OS:       mapStringMap(ps.OS),
		Arch:     mapStringMap(ps.Arch),
		Platform: mapPlatformMap(ps.Platform),
	}
	return result, errors
}

// MapSlice applies a function that processes slices of strings to the strings
// in "ps" and returns a new PlatformStrings with the results.
func (ps *PlatformStrings) MapSlice(f func([]string) ([]string, error)) (PlatformStrings, []error) {
	var errors []error

	mapSlice := func(ss []string) []string {
		rs, err := f(ss)
		if err != nil {
			errors = append(errors, err)
			return nil
		}
		return rs
	}

	mapStringMap := func(m map[string][]string) map[string][]string {
		if m == nil {
			return nil
		}
		rm := make(map[string][]string)
		for k, ss := range m {
			ss = mapSlice(ss)
			if len(ss) > 0 {
				rm[k] = ss
			}
		}
		if len(rm) == 0 {
			return nil
		}
		return rm
	}

	mapPlatformMap := func(m map[config.Platform][]string) map[config.Platform][]string {
		if m == nil {
			return nil
		}
		rm := make(map[config.Platform][]string)
		for k, ss := range m {
			ss = mapSlice(ss)
			if len(ss) > 0 {
				rm[k] = ss
			}
		}
		if len(rm) == 0 {
			return nil
		}
		return rm
	}

	result := PlatformStrings{
		Generic:  mapSlice(ps.Generic),
		OS:       mapStringMap(ps.OS),
		Arch:     mapStringMap(ps.Arch),
		Platform: mapPlatformMap(ps.Platform),
	}
	return result, errors
}
