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

	bf "github.com/bazelbuild/buildtools/build"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/config"
)

func diffFile(c *config.Config, file *bf.File) error {
	f, err := ioutil.TempFile("", c.DefaultBuildFileName())
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())
	defer f.Close()
	if _, err := f.Write(bf.Format(file)); err != nil {
		return err
	}
	if err := f.Sync(); err != nil {
		return err
	}

	cmd := exec.Command("diff", "-u", "--new-file", file.Path, f.Name())
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err = cmd.Run()
	if _, ok := err.(*exec.ExitError); ok {
		// diff returns non-zero when files are different. This is not an error.
		return nil
	}
	return err
}
