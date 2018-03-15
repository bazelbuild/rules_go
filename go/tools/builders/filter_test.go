/* Copyright 2016 The Bazel Authors. All rights reserved.

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

package main

import (
	"go/build"
	"io/ioutil"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"testing"
)

var testfiles = map[string]string{
	"cgo.go": `
//+build cgo

package tags

/*
#include <stdio.h>
#include <stdlib.h>

void myprint(char* s) {
		printf("%s", s);
}
*/

import "C"

func main() {
	C.myprint("hello")
}
`,
	"extra.go": `
//+build a,b b,c

package tags
`,
	"ignore.go": `
//+build ignore

package tags
`,
	"normal.go": `
package tags
`,
	"on_darwin.go": `
package tags
`,
	"system.go": `
//+build arm,darwin linux,amd64

package tags
`,
}

func TestTags(t *testing.T) {
	tempdir, err := ioutil.TempDir("", "goruletest")
	if err != nil {
		t.Fatalf("Error creating temporary directory: %v", err)
	}
	defer os.RemoveAll(tempdir)

	input := []string{}
	for k, v := range testfiles {
		p := filepath.Join(tempdir, k)
		if err := ioutil.WriteFile(p, []byte(v), 0644); err != nil {
			t.Fatalf("WriteFile(%s): %v", p, err)
		}
		input = append(input, k)
	}
	sort.Strings(input)

	wd, err := os.Getwd()
	if err != nil {
		t.Fatalf("Getwd: %v", err)
	}

	err = os.Chdir(tempdir)
	if err != nil {
		t.Fatalf("Chdir(%s): %v", tempdir, err)
	}
	defer os.Chdir(wd)

	bctx := build.Default
	// Always fake the os and arch
	bctx.GOOS = "darwin"
	bctx.GOARCH = "amd64"
	bctx.CgoEnabled = false
	runTest(t, bctx, input, []string{"normal.go", "on_darwin.go"})
	bctx.GOOS = "linux"
	runTest(t, bctx, input, []string{"normal.go", "system.go"})
	bctx.GOARCH = "arm"
	runTest(t, bctx, input, []string{"normal.go"})
	bctx.BuildTags = []string{"a", "b"}
	runTest(t, bctx, input, []string{"extra.go", "normal.go"})
	bctx.BuildTags = []string{"a", "c"}
	runTest(t, bctx, input, []string{"normal.go"})
	bctx.CgoEnabled = true
	runTest(t, bctx, input, []string{"cgo.go", "normal.go"})
}

func runTest(t *testing.T, bctx build.Context, inputs []string, expect []string) {
	got, err := filterFiles(bctx, inputs)
	if err != nil {
		t.Errorf("filter %v,%v,%v,%v failed: %v", bctx.GOOS, bctx.GOARCH, bctx.CgoEnabled, bctx.BuildTags, err)
	}
	if !reflect.DeepEqual(expect, got) {
		t.Errorf("filter %v,%v,%v,%v: expect %v got %v", bctx.GOOS, bctx.GOARCH, bctx.CgoEnabled, bctx.BuildTags, expect, got)
	}
}

// abs is a dummy env.go abs to avoid depending on env.go and flags.go.
func abs(p string) string {
	return p
}
