// Copyright 2020 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package wrapper_test

import (
	"io/ioutil"
	"os"
	"os/exec"
	"testing"
)

func Test(t *testing.T) {
	if _, ok := os.LookupEnv("RUNFILES_MANIFEST_FILE"); ok {
		t.Skipf("test only applicable with a runfiles directory")
	}

	tmpLog, err := ioutil.TempFile("", "tmp.xml")
	if err != nil {
		t.Fatal(err)
	}
	defer func() {
		tmpLog.Close()
		os.Remove(tmpLog.Name())
	}()

	arg := os.Args[1]
	cmd := exec.Command(arg)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = append(os.Environ(), "GO_TEST_WRAP=1", "XML_OUTPUT_FILE="+tmpLog.Name())
	if err := cmd.Run(); err != nil {
		t.Fatalf("running wrapped_test: %v", err)
	}
}
