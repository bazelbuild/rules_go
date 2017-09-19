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
	"log"
	"regexp"
	"strings"

	bf "github.com/bazelbuild/buildtools/build"
)

// Directive is a key-value pair extracted from a top-level comment in
// a build file. Directives have the following format:
//
//     # gazelle:key value
//
// Keys may not contain spaces. Values may be empty and may contain spaces,
// but surrounding space is trimmed.
type Directive struct {
	Key, Value string
}

// ParseDirectives scans f for Gazelle directives. Directives related to
// the configuration will be applied to a copy of c, which is returned.
// c may be nil, in which case changes are applied to the default configuration.
// The full list of directives is returned in either case.
//
// The following configuration directives are recognized:
//
// * build_tags - comma-separated list of build tags that will be considered
//   true on all platforms. Sets GenericTags.
// * build_file_name - comma-separated list of build file names. Sets
//   ValidBuildFileNames.
//
// TODO(jayconrod): support GoPrefix, and DepMode at least.
func ParseDirectives(f *bf.File, c *Config) (*Config, []Directive) {
	var modified Config
	if c != nil {
		modified = *c
	}

	var directives []Directive
	for _, s := range f.Stmt {
		comments := append(s.Comment().Before, s.Comment().After...)
		for _, com := range comments {
			match := directiveRe.FindStringSubmatch(com.Token)
			if match == nil {
				continue
			}
			d := Directive{match[1], match[2]}
			directives = append(directives, d)

			switch d.Key {
			case "build_tags":
				if err := modified.SetBuildTags(d.Value); err != nil {
					log.Print(err)
				}
				modified.PreprocessTags()
			case "build_file_name":
				modified.ValidBuildFileNames = strings.Split(d.Value, ",")
			}
		}
	}
	return &modified, directives
}

var directiveRe = regexp.MustCompile(`^#\s*gazelle:(\w+)\s*(.*?)\s*$`)
