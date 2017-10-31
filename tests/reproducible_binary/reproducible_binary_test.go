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

// reproducible_binary_test checks that a given binary DOES NOT contain
// strings that match the GOROOT, the current user's name, or the
// current user's home directory.
package main

import (
	"bytes"
	"io/ioutil"
	"log"
	"os"
	"os/user"
	"regexp"
	"testing"
)

var allStrings [][]byte
var currentUser *user.User

func TestMain(m *testing.M) {
	log.SetFlags(0)
	if len(os.Args) != 2 {
		log.Fatalf("usage: %s <binary>\n", os.Args[0])
	}

	binaryData, err := ioutil.ReadFile(os.Args[1])
	if err != nil {
		log.Fatal(err)
	}
	stringRex := regexp.MustCompile(`[[:graph:]]{3,}`)
	allStrings = stringRex.FindAll(binaryData, -1)

	currentUser, err = user.Current()
	if err != nil {
		currentUser = nil
	}

	os.Exit(m.Run())
}

// TestStandardPath checks that source paths from the standard library
// are trimmed. We just check one known source file.
func TestStandardPath(t *testing.T) {
	want := []byte("GOROOT/src/fmt/format.go")
	for _, s := range allStrings {
		if bytes.HasSuffix(s, []byte("fmt/format.go")) && !bytes.Equal(s, want) {
			t.Fatalf("got %q; want %q", s, want)
		}
	}
}

// TestUserNameAndHome checks the user name and home directory do not
// appear in strings from the binary.
func TestUserNameAndHome(t *testing.T) {
	if currentUser == nil || len(currentUser.Username) < 4 {
		t.Skip()
	}
	for _, s := range allStrings {
		if currentUser.Username != "" && bytes.Contains(s, []byte(currentUser.Username)) {
			t.Errorf("binary contains username %q in string %q", currentUser.Username, s)
			continue
		}
		if currentUser.HomeDir != "" && bytes.Contains(s, []byte(currentUser.HomeDir)) {
			t.Errorf("binary contains home dir %q in string %q", currentUser.HomeDir, s)
		}
	}
}
