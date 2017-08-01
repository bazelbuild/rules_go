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

package config

import (
	"fmt"
)

// Config holds information about how Gazelle should run. This is mostly
// based on command-line arguments.
type Config struct {
	// Dirs is a list of absolute paths to directories where Gazelle should run.
	Dirs []string

	// RepoRoot is the absolute path to the root directory of the repository.
	RepoRoot string

	// ValidBuildFileNames is a list of base names that are considered valid
	// build files. Some repositories may have files named "BUILD" that are not
	// used by Bazel and should be ignored. Must contain at least one string.
	ValidBuildFileNames []string

	// GenericTags is a set of build constraints that are true on all platforms.
	// It should not be nil.
	GenericTags BuildTags

	// Platforms contains a set of build constraints for each platform. Each set
	// should include GenericTags. It should not be nil.
	Platforms PlatformTags

	// GoPrefix is the portion of the import path for the root of this repository.
	// This is used to map imports to labels within the repository.
	GoPrefix string

	// DepMode determines how imports outside of GoPrefix are resolved.
	DepMode DependencyMode

	// KnownImports is a list of imports to add to the external resolver cache
	KnownImports []string
}

var DefaultValidBuildFileNames = []string{"BUILD.bazel", "BUILD"}

func (c *Config) IsValidBuildFileName(name string) bool {
	for _, n := range c.ValidBuildFileNames {
		if name == n {
			return true
		}
	}
	return false
}

func (c *Config) DefaultBuildFileName() string {
	return c.ValidBuildFileNames[0]
}

// BuildTags is a set of build constraints.
type BuildTags map[string]bool

// PlatformTags is a map from config_setting labels (for example,
// "@io_bazel_rules_go//go/platform:linux_amd64") to a sets of build tags
// that are true on each platform (for example, "linux,amd64").
type PlatformTags map[string]BuildTags

// DefaultPlatformTags is the default set of platforms that Gazelle
// will generate files for. These are the platforms that both Go and Bazel
// support.
var DefaultPlatformTags PlatformTags

func init() {
	DefaultPlatformTags = make(PlatformTags)
	arch := "amd64"
	for _, os := range []string{"darwin", "linux", "windows"} {
		label := fmt.Sprintf("@%s//go/platform:%s_%s", RulesGoRepoName, os, arch)
		DefaultPlatformTags[label] = BuildTags{arch: true, os: true}
	}
}

// PreprocessTags performs some automatic processing on generic and
// platform-specific tags before they are used to match files.
func (c *Config) PreprocessTags() {
	c.GenericTags["cgo"] = true
	c.GenericTags["gc"] = true
	for _, platformTags := range c.Platforms {
		for t, _ := range c.GenericTags {
			platformTags[t] = true
		}
	}
}

// DependencyMode determines how imports of packages outside of the prefix
// are resolved.
type DependencyMode int

const (
	// ExternalMode indicates imports should be resolved to external dependencies
	// (declared in WORKSPACE).
	ExternalMode DependencyMode = iota

	// VendorMode indicates imports should be resolved to libraries in the
	// vendor directory.
	VendorMode
)

// DependencyModeFromString converts a string from the command line
// to a DependencyMode. Valid strings are "external", "vendor". An error will
// be returned for an invalid string.
func DependencyModeFromString(s string) (DependencyMode, error) {
	switch s {
	case "external":
		return ExternalMode, nil
	case "vendored":
		return VendorMode, nil
	default:
		return 0, fmt.Errorf("unrecognized dependency mode: %q", s)
	}
}
