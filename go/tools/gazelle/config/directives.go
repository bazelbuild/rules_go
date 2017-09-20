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

// Top-level directives apply to the whole package or build file. They must
// appear before the first statement.
var knownTopLevelDirectives = map[string]bool{
	"build_file_name": true,
	"build_tags":      true,
	"exclude":         true,
	"ignore":          true,
}

// TODO(jayconrod): annotation directives will apply to an individual rule.
// They must appear in the block of comments above that rule.

// ParseDirectives scans f for Gazelle directives. The full list of directives
// is returned. Errors are reported for unrecognized directives and directives
// out of place (after the first statement).
func ParseDirectives(f *bf.File) []Directive {
	var directives []Directive
	beforeStmt := true
	parseComment := func(com bf.Comment) {
		match := directiveRe.FindStringSubmatch(com.Token)
		if match == nil {
			return
		}
		key, value := match[1], match[2]
		if _, ok := knownTopLevelDirectives[key]; !ok {
			log.Printf("%s:%d: unknown directive: %s", f.Path, com.Start.Line, com.Token)
			return
		}
		if !beforeStmt {
			log.Printf("%s:%d: top-level directive may not appear after the first statement", f.Path, com.Start.Line)
			return
		}
		directives = append(directives, Directive{key, value})
	}

	for _, s := range f.Stmt {
		coms := s.Comment()
		for _, com := range coms.Before {
			parseComment(com)
		}
		_, isComment := s.(*bf.CommentBlock)
		beforeStmt = beforeStmt && isComment
		for _, com := range coms.Suffix {
			parseComment(com)
		}
		for _, com := range coms.After {
			parseComment(com)
		}
	}
	return directives
}

var directiveRe = regexp.MustCompile(`^#\s*gazelle:(\w+)\s*(.*?)\s*$`)

// ApplyDirectives applies directives that modify the configuration to a
// copy of c, which is returned. If there are no configuration directives,
// c is returned unmodified.
func ApplyDirectives(c *Config, directives []Directive) *Config {
	modified := *c
	didModify := false
	for _, d := range directives {
		switch d.Key {
		case "build_tags":
			if err := modified.SetBuildTags(d.Value); err != nil {
				log.Print(err)
				modified.GenericTags = c.GenericTags
			} else {
				modified.PreprocessTags()
				didModify = true
			}
		case "build_file_name":
			modified.ValidBuildFileNames = strings.Split(d.Value, ",")
			didModify = true
		}
	}
	if !didModify {
		return c
	}
	return &modified
}
