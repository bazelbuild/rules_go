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
	"sort"
)

// Platform represents a GOOS/GOARCH pair. When Platform is used to describe
// sources, dependencies, or flags, either OS or Arch may be empty.
type Platform struct {
	OS, Arch string
}

// String returns OS, Arch, or "OS_Arch" if both are set. This must match
// the names of config_setting rules in @io_bazel_rules_go//go/platform.
func (p Platform) String() string {
	switch {
	case p.OS != "" && p.Arch != "":
		return p.OS + "_" + p.Arch
	case p.OS != "":
		return p.OS
	case p.Arch != "":
		return p.Arch
	default:
		return ""
	}
}

// KnownPlatforms is the set of target platforms that Go supports. Gazelle
// will generate multi-platform build files using these tags. rules_go and
// Bazel may not actually support all of these.
var KnownPlatforms = []Platform{
	{"android", "arm"},
	{"darwin", "386"},
	{"darwin", "amd64"},
	{"darwin", "arm"},
	{"darwin", "arm64"},
	{"dragonfly", "amd64"},
	{"freebsd", "386"},
	{"freebsd", "amd64"},
	{"freebsd", "arm"},
	{"linux", "386"},
	{"linux", "amd64"},
	{"linux", "arm"},
	{"linux", "arm64"},
	{"linux", "ppc64"},
	{"linux", "ppc64le"},
	{"linux", "mips"},
	{"linux", "mipsle"},
	{"linux", "mips64"},
	{"linux", "mips64le"},
	{"netbsd", "386"},
	{"netbsd", "amd64"},
	{"netbsd", "arm"},
	{"openbsd", "386"},
	{"openbsd", "amd64"},
	{"openbsd", "arm"},
	{"plan9", "386"},
	{"plan9", "amd64"},
	{"solaris", "amd64"},
	{"windows", "386"},
	{"windows", "amd64"},
}

var (
	// KnownOSs is the sorted list of operating systems that Go supports.
	KnownOSs []string

	// KnownOSSet is the set of operating systems that Go supports.
	KnownOSSet map[string]bool

	// KnownArchs is the sorted list of architectures that Go supports.
	KnownArchs []string

	// KnownArchSet is the set of architectures that Go supports.
	KnownArchSet map[string]bool
)

func init() {
	KnownOSSet = make(map[string]bool)
	KnownArchSet = make(map[string]bool)
	for _, p := range KnownPlatforms {
		KnownOSSet[p.OS] = true
		KnownArchSet[p.Arch] = true
	}
	KnownOSs = make([]string, 0, len(KnownOSSet))
	KnownArchs = make([]string, 0, len(KnownArchSet))
	for os, _ := range KnownOSSet {
		KnownOSs = append(KnownOSs, os)
	}
	for arch, _ := range KnownArchSet {
		KnownArchs = append(KnownArchs, arch)
	}
	sort.Strings(KnownOSs)
	sort.Strings(KnownArchs)
}

// TODO(jayconrod): remove these after Bazel 0.8 is released and the
// ExperimentalPlatforms flag is removed from Config.
var (
	DefaultPlatforms = []Platform{
		{"darwin", "amd64"},
		{"linux", "amd64"},
		{"windows", "amd64"},
	}

	DefaultOSSet = map[string]bool{
		"darwin":  true,
		"linux":   true,
		"windows": true,
	}

	DefaultArchSet = map[string]bool{
		"amd64": true,
	}
)
