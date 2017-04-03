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
	"io/ioutil"
	"os"
	"os/exec"

	bzl "github.com/bazelbuild/buildifier/build"
)

func diffFile(file *bzl.File) error {
	f, err := ioutil.TempFile("", *buildFileName)
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())
	defer f.Close()
	if _, err := f.Write(bzl.Format(file)); err != nil {
		return err
	}
	if err := f.Sync(); err != nil {
		return err
	}

	origFileName := file.Path
	if _, err := os.Stat(origFileName); os.IsNotExist(err) {
		origFileName = os.DevNull
	}
	cmd := exec.Command("diff", "-u", origFileName, f.Name())
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err = cmd.Run()
	if _, ok := err.(*exec.ExitError); ok {
		// diff returns non-zero when files are different. This is not an error.
		return nil
	}
	return err
}
