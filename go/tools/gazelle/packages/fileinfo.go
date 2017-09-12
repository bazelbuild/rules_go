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
	"bufio"
	"log"
	"os"
	"path"
	"path/filepath"
	"strings"
)

// fileInfo holds information used to decide how to build a file. This
// information comes from the file's name, from package and import declarations
// (in .go files), and from +build and cgo comments.
type fileInfo struct {
	path, rel, name, ext string

	// packageName is the Go package name of a .go file, without the
	// "_test" suffix if it was present. It is empty for non-Go files.
	packageName string

	// importPath is the canonical import path for the package this file
	// belongs to. Will be empty file files that don't specify this.
	importPath string

	// category is the type of file, based on extension.
	category extCategory

	// isTest is true if the file stem (the part before the extension)
	// ends with "_test.go". This is never true for non-Go files.
	isTest bool

	// isXTest is true for test Go files whose declared package name ends
	// with "_test".
	isXTest bool

	// imports is a list of packages imported by a file. It does not include
	// "C" or anything from the standard library.
	imports []string

	// isCgo is true for .go files that import "C".
	isCgo bool

	// goos and goarch contain the OS and architecture suffixes in the filename,
	// if they were present.
	goos, goarch string

	// tags is a list of build tag lines. Each entry is the trimmed text of
	// a line after a "+build" prefix.
	tags []string

	// copts and clinkopts contain flags that are part of CFLAGS, CPPFLAGS,
	// CXXFLAGS, and LDFLAGS directives in cgo comments.
	copts, clinkopts []taggedOpts

	// hasServices indicates whether a .proto file has service definitions.
	hasServices bool
}

// taggedOpts a list of compile or link options which should only be applied
// if the given set of build tags are satisfied. These options have already
// been tokenized using the same algorithm that "go build" uses.
type taggedOpts struct {
	tags string
	opts []string
}

// optSeparator is a special option string that is inserted after each group
// of options that appeared in the same #cgo directive.
const optSeparator = "\x1D"

// extCategory indicates how a file should be treated, based on extension.
type extCategory int

const (
	// ignoredExt is applied to files which are not part of a build.
	ignoredExt extCategory = iota

	// unsupportedExt is applied to files that we don't support but would be
	// built with "go build".
	unsupportedExt

	// goExt is applied to .go files.
	goExt

	// cExt is applied to C and C++ files.
	cExt

	// hExt is applied to header files. If cgo code is present, these may be
	// C or C++ headers. If not, they are treated as Go assembly headers.
	hExt

	// sExt is applied to Go assembly files, ending with .s.
	sExt

	// csExt is applied to other assembly files, ending with .S. These are built
	// with the C compiler if cgo code is present.
	csExt

	// protoExt is applied to .proto files.
	protoExt
)

// fileNameInfo returns information that can be inferred from the name of
// a file. It does not read data from the file.
func fileNameInfo(dir, rel, name string) fileInfo {
	ext := path.Ext(name)

	// Categorize the file based on extension. Based on go/build.Context.Import.
	var category extCategory
	switch ext {
	case ".go":
		category = goExt
	case ".c", ".cc", ".cpp", ".cxx":
		category = cExt
	case ".h", ".hh", ".hpp", ".hxx":
		category = hExt
	case ".s":
		category = sExt
	case ".S":
		category = csExt
	case ".proto":
		category = protoExt
	case ".m", ".f", ".F", ".for", ".f90", ".swig", ".swigcxx", ".syso":
		category = unsupportedExt
	default:
		category = ignoredExt
	}

	// Determine test, goos, and goarch. This is intended to match the logic
	// in goodOSArchFile in go/build.
	var isTest bool
	var goos, goarch string
	l := strings.Split(name[:len(name)-len(ext)], "_")
	if len(l) >= 2 && l[len(l)-1] == "test" {
		isTest = category == goExt
		l = l[:len(l)-1]
	}
	switch {
	case len(l) >= 3 && knownOS[l[len(l)-2]] && knownArch[l[len(l)-1]]:
		goos = l[len(l)-2]
		goarch = l[len(l)-1]
	case len(l) >= 2 && knownOS[l[len(l)-1]]:
		goos = l[len(l)-1]
	case len(l) >= 2 && knownArch[l[len(l)-1]]:
		goarch = l[len(l)-1]
	}

	return fileInfo{
		path:     filepath.Join(dir, name),
		rel:      rel,
		name:     name,
		ext:      ext,
		category: category,
		isTest:   isTest,
		goos:     goos,
		goarch:   goarch,
	}
}

// JoinOptions combines shell options grouped by a special separator token
// and returns a string for each group. The group strings will be escaped
// such that the original options can be recovered after Bourne shell
// tokenization.
func JoinOptions(opts []string) []string {
	var groups []string
	begin := 0
	for i := 0; i < len(opts); i++ {
		if opts[i] == optSeparator {
			groups = append(groups, joinOptionGroup(opts[begin:i]))
			begin = i + 1
		}
	}
	if begin != len(opts) {
		log.Panicf("JoinOptions: opts were not properly grouped: %#v", opts)
	}
	return groups
}

func joinOptionGroup(opts []string) string {
	for i, opt := range opts {
		opts[i] = escapeOption(opt)
	}
	return strings.Join(opts, " ")
}

func escapeOption(opt string) string {
	return strings.NewReplacer(
		`\`, `\\`,
		`'`, `\'`,
		`"`, `\"`,
		` `, `\ `,
		"\t", "\\\t",
		"\n", "\\\n",
		"\r", "\\\r",
	).Replace(opt)
}

// isStandard determines if importpath points a Go standard package.
func isStandard(goPrefix, importpath string) bool {
	seg := strings.SplitN(importpath, "/", 2)[0]
	return !strings.Contains(seg, ".") && !strings.HasPrefix(importpath, goPrefix+"/")
}

// otherFileInfo returns information about a non-.go file. It will parse
// part of the file to determine build tags. If the file can't be read, an
// error will be logged, and partial information will be returned.
func otherFileInfo(dir, rel, name string) fileInfo {
	info := fileNameInfo(dir, rel, name)
	if info.category == ignoredExt {
		return info
	}
	if info.category == unsupportedExt {
		log.Printf("%s: warning: file extension not yet supported", info.path)
		return info
	}

	tags, err := readTags(info.path)
	if err != nil {
		log.Printf("%s: error reading file: %v", info.path, err)
		return info
	}
	info.tags = tags
	return info
}

// Copied from go/build. Keep in sync as new platforms are added.
const goosList = "android darwin dragonfly freebsd linux nacl netbsd openbsd plan9 solaris windows zos "
const goarchList = "386 amd64 amd64p32 arm armbe arm64 arm64be ppc64 ppc64le mips mipsle mips64 mips64le mips64p32 mips64p32le ppc s390 s390x sparc sparc64 "

var knownOS = make(map[string]bool)
var knownArch = make(map[string]bool)

func init() {
	for _, v := range strings.Fields(goosList) {
		knownOS[v] = true
	}
	for _, v := range strings.Fields(goarchList) {
		knownArch[v] = true
	}
}

// readTags reads and extracts build tags from the block of comments and
// newlines and blank lines at the start of a file which is separated from the
// rest of the file by a blank line. Each string in the returned slice is
// the trimmed text of a line after a "+build" prefix.
// Based on go/build.Context.shouldBuild.
func readTags(path string) ([]string, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)

	// Pass 1: Identify leading run of // comments and blank lines,
	// which must be followed by a blank line.
	var lines []string
	end := 0
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			end = len(lines)
			continue
		}
		if strings.HasPrefix(line, "//") {
			lines = append(lines, line[len("//"):])
			continue
		}
		break
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	lines = lines[:end]

	// Pass 2: Process each line in the run.
	var buildComments []string
	for _, line := range lines {
		fields := strings.Fields(line)
		if len(fields) > 0 && fields[0] == "+build" {
			buildComments = append(buildComments, strings.Join(fields[1:], " "))
		}
	}
	return buildComments, nil
}

// hasConstraints returns true if a file has goos, goarch filename suffixes
// or build tags.
func (fi *fileInfo) hasConstraints() bool {
	return fi.goos != "" || fi.goarch != "" || len(fi.tags) > 0
}

// checkConstraints determines whether a file should be built on a platform
// with the given tags. It returns true for files without constraints.
func (fi *fileInfo) checkConstraints(tags map[string]bool) bool {
	// TODO: linux should match on android.
	if fi.goos != "" {
		if _, ok := tags[fi.goos]; !ok {
			return false
		}
	}
	if fi.goarch != "" {
		if _, ok := tags[fi.goarch]; !ok {
			return false
		}
	}

	for _, line := range fi.tags {
		if !checkTags(line, tags) {
			return false
		}
	}
	return true
}

// checkTags determines whether the build tags on a given line are satisfied.
// The line should be a whitespace-separated list of groups of comma-separated
// tags. The constraints are satisfied for the line if any of the groups are
// satisfied. A group is satisfied if all of the tags in it are true. A tag can
// be negated with a "!" prefix, but double negatation ("!!") is not allowed.
func checkTags(line string, tags map[string]bool) bool {
	// TODO: linux should match on android.
	lineOk := false
	for _, group := range strings.Fields(line) {
		groupOk := true
		for _, tag := range strings.Split(group, ",") {
			if strings.HasPrefix(tag, "!!") { // bad syntax, reject always
				return false
			}
			not := strings.HasPrefix(tag, "!")
			if not {
				tag = tag[1:]
			}
			if isReleaseTag(tag) {
				// Release tags are treated as "unknown" and are considered true,
				// whether or not they are negated.
				continue
			}
			_, ok := tags[tag]
			groupOk = groupOk && (not != ok)
		}
		lineOk = lineOk || groupOk
	}
	return lineOk
}

// isReleaseTag returns whether the tag matches the pattern "go[0-9]\.[0-9]+".
func isReleaseTag(tag string) bool {
	if len(tag) < 5 || !strings.HasPrefix(tag, "go") {
		return false
	}
	if tag[2] < '0' || tag[2] > '9' || tag[3] != '.' {
		return false
	}
	for _, c := range tag[4:] {
		if c < '0' || c > '9' {
			return false
		}
	}
	return true
}
