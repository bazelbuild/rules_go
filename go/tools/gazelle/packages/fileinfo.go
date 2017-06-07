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
	"bytes"
	"errors"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path"
	"path/filepath"
	"strconv"
	"strings"
	"unicode"
	"unicode/utf8"
)

// fileInfo holds information used to decide how to build a file. This
// information comes from the file's name, from package and import declarations
// (in .go files), and from +build and cgo comments.
type fileInfo struct {
	path, dir, name, ext string

	// packageName is the Go package name of a .go file, without the
	// "_test" suffix if it was present. It is empty for non-Go files.
	packageName string

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
}

// taggedOpts a list of compile or link options which should only be applied
// if the given set of build tags are satisfied.
type taggedOpts struct {
	tags string
	opts []string
}

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
)

// fileNameInfo returns information that can be inferred from the name of
// a file. It does not read data from the file.
func fileNameInfo(dir, name string) fileInfo {
	ext := path.Ext(name)

	// Determine test, goos, and goarch. This is intended to match the logic
	// in goodOSArchFile in go/build.
	var isTest bool
	var goos, goarch string
	l := strings.Split(name[:len(name)-len(ext)], "_")
	if len(l) >= 2 && l[len(l)-1] == "test" {
		isTest = true
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
	case ".m", ".f", ".F", ".for", ".f90", ".swig", ".swigcxx", ".syso":
		category = unsupportedExt
	default:
		category = ignoredExt
	}

	return fileInfo{
		path:     filepath.Join(dir, name),
		dir:      dir,
		name:     name,
		ext:      ext,
		category: category,
		isTest:   isTest,
		goos:     goos,
		goarch:   goarch,
	}
}

// goFileInfo returns information about a .go file. It will parse part of the
// file to determine the package name and imports.
// This function is intended to match go/build.Context.Import.
func (pr *packageReader) goFileInfo(name string) (fileInfo, error) {
	info := fileNameInfo(pr.dir, name)
	fset := token.NewFileSet()
	pf, err := parser.ParseFile(fset, info.path, nil, parser.ImportsOnly|parser.ParseComments)
	if err != nil {
		return fileInfo{}, err
	}

	info.packageName = pf.Name.Name
	if info.isTest && strings.HasSuffix(info.packageName, "_test") {
		info.isXTest = true
		info.packageName = info.packageName[:len(info.packageName)-len("_test")]
	}

	for _, decl := range pf.Decls {
		d, ok := decl.(*ast.GenDecl)
		if !ok {
			continue
		}
		for _, dspec := range d.Specs {
			spec, ok := dspec.(*ast.ImportSpec)
			if !ok {
				continue
			}
			quoted := spec.Path.Value
			path, err := strconv.Unquote(quoted)
			if err != nil {
				return fileInfo{}, err
			}

			if path == "C" {
				if info.isTest {
					return fileInfo{}, fmt.Errorf("%s: use of cgo in test not supported", info.path)
				}
				info.isCgo = true
				cg := spec.Doc
				if cg == nil && len(d.Specs) == 1 {
					cg = d.Doc
				}
				if cg != nil {
					if err := pr.saveCgo(&info, cg); err != nil {
						return fileInfo{}, err
					}
				}
			} else if !pr.isStandard(path) {
				info.imports = append(info.imports, path)
			}
		}
	}

	tags, err := readTags(info.path)
	if err != nil {
		return fileInfo{}, err
	}
	info.tags = tags

	return info, nil
}

// saveCgo extracts CFLAGS, CPPFLAGS, CXXFLAGS, and LDFLAGS directives
// from a comment above a "C" import. This is intended to match logic in
// go/build.Context.saveCgo.
func (pr *packageReader) saveCgo(info *fileInfo, cg *ast.CommentGroup) error {
	text := cg.Text()
	for _, line := range strings.Split(text, "\n") {
		orig := line

		// Line is
		//	#cgo [GOOS/GOARCH...] LDFLAGS: stuff
		//
		line = strings.TrimSpace(line)
		if len(line) < 5 || line[:4] != "#cgo" || (line[4] != ' ' && line[4] != '\t') {
			continue
		}

		// Split at colon.
		line = strings.TrimSpace(line[4:])
		i := strings.Index(line, ":")
		if i < 0 {
			return fmt.Errorf("%s: invalid #cgo line: %s", info.path, orig)
		}
		line, optstr := strings.TrimSpace(line[:i]), strings.TrimSpace(line[i+1:])

		// Parse tags and verb.
		f := strings.Fields(line)
		if len(f) < 1 {
			return fmt.Errorf("%s: invalid #cgo line: %s", info.path, orig)
		}
		verb := f[len(f)-1]
		tags := strings.Join(f[:len(f)-1], " ")

		// Parse options.
		opts, err := splitQuoted(optstr)
		if err != nil {
			return fmt.Errorf("%s: invalid #cgo line: %s", info.path, orig)
		}
		var ok bool
		for i, opt := range opts {
			if opt, ok = expandSrcDir(opt, info.dir); !ok {
				return fmt.Errorf("%s: malformed #cgo argument: %s", info.path, orig)
			}
			opts[i] = opt
		}

		// Add tags to appropriate list.
		switch verb {
		case "CFLAGS", "CPPFLAGS", "CXXFLAGS":
			info.copts = append(info.copts, taggedOpts{tags, opts})
		case "LDFLAGS":
			info.clinkopts = append(info.clinkopts, taggedOpts{tags, opts})
		case "pkg-config":
			pr.warn(fmt.Errorf("%s: pkg-config not supported: %s", info.path, orig))
		default:
			return fmt.Errorf("%s: invalid #cgo verb: %s", info.path, orig)
		}
	}
	return nil
}

// splitQuoted splits the string s around each instance of one or more consecutive
// white space characters while taking into account quotes and escaping, and
// returns an array of substrings of s or an empty list if s contains only white space.
// Single quotes and double quotes are recognized to prevent splitting within the
// quoted region, and are removed from the resulting substrings. If a quote in s
// isn't closed err will be set and r will have the unclosed argument as the
// last element. The backslash is used for escaping.
//
// For example, the following string:
//
//     a b:"c d" 'e''f'  "g\""
//
// Would be parsed as:
//
//     []string{"a", "b:c d", "ef", `g"`}
//
// Copied from go/build.splitQuoted
func splitQuoted(s string) (r []string, err error) {
	var args []string
	arg := make([]rune, len(s))
	escaped := false
	quoted := false
	quote := '\x00'
	i := 0
	for _, rune := range s {
		switch {
		case escaped:
			escaped = false
		case rune == '\\':
			escaped = true
			continue
		case quote != '\x00':
			if rune == quote {
				quote = '\x00'
				continue
			}
		case rune == '"' || rune == '\'':
			quoted = true
			quote = rune
			continue
		case unicode.IsSpace(rune):
			if quoted || i > 0 {
				quoted = false
				args = append(args, string(arg[:i]))
				i = 0
			}
			continue
		}
		arg[i] = rune
		i++
	}
	if quoted || i > 0 {
		args = append(args, string(arg[:i]))
	}
	if quote != 0 {
		err = errors.New("unclosed quote")
	} else if escaped {
		err = errors.New("unfinished escaping")
	}
	return args, err
}

// expandSrcDir expands any occurrence of ${SRCDIR}, making sure
// the result is safe for the shell.
//
// Copied from go/build.expandSrcDir
func expandSrcDir(str string, srcdir string) (string, bool) {
	// "\" delimited paths cause safeCgoName to fail
	// so convert native paths with a different delimiter
	// to "/" before starting (eg: on windows).
	srcdir = filepath.ToSlash(srcdir)

	// Spaces are tolerated in ${SRCDIR}, but not anywhere else.
	chunks := strings.Split(str, "${SRCDIR}")
	if len(chunks) < 2 {
		return str, safeCgoName(str, false)
	}
	ok := true
	for _, chunk := range chunks {
		ok = ok && (chunk == "" || safeCgoName(chunk, false))
	}
	ok = ok && (srcdir == "" || safeCgoName(srcdir, true))
	res := strings.Join(chunks, srcdir)
	return res, ok && res != ""
}

// NOTE: $ is not safe for the shell, but it is allowed here because of linker options like -Wl,$ORIGIN.
// We never pass these arguments to a shell (just to programs we construct argv for), so this should be okay.
// See golang.org/issue/6038.
// The @ is for OS X. See golang.org/issue/13720.
// The % is for Jenkins. See golang.org/issue/16959.
const safeString = "+-.,/0123456789=ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz:$@%"
const safeSpaces = " "

var safeBytes = []byte(safeSpaces + safeString)

// Copied from go/build.safeCgoName
func safeCgoName(s string, spaces bool) bool {
	if s == "" {
		return false
	}
	safe := safeBytes
	if !spaces {
		safe = safe[len(safeSpaces):]
	}
	for i := 0; i < len(s); i++ {
		if c := s[i]; c < utf8.RuneSelf && bytes.IndexByte(safe, c) < 0 {
			return false
		}
	}
	return true
}

// isStandard determines if importpath points a Go standard package.
func (pr *packageReader) isStandard(importpath string) bool {
	seg := strings.SplitN(importpath, "/", 2)[0]
	return !strings.Contains(seg, ".") && !strings.HasPrefix(importpath, pr.goPrefix+"/")
}

// otherFileInfo returns information about a non-.go file. It will parse
// part of the file to determine build tags.
func (pr *packageReader) otherFileInfo(name string) (fileInfo, error) {
	info := fileNameInfo(pr.dir, name)
	if info.category == ignoredExt {
		return info, nil
	}
	if info.category == unsupportedExt {
		return info, fmt.Errorf("%s: file extension not yet supported", name)
	}

	if tags, err := readTags(info.path); err != nil {
		pr.warn(err)
	} else {
		info.tags = tags
	}
	return info, nil
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
			_, ok := tags[tag]
			groupOk = groupOk && (not != ok)
		}
		lineOk = lineOk || groupOk
	}
	return lineOk
}
