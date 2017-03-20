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
	"path/filepath"

	bzl "github.com/bazelbuild/buildifier/build"
)

func fixFile(file *bzl.File) error {
	if err := ioutil.WriteFile(file.Path, bzl.Format(file), 0644); err != nil {
		return err
	}
	if filepath.Base(file.Path) != *buildFileName {
		return os.Rename(file.Path, filepath.Join(filepath.Dir(file.Path), *buildFileName))
	}
	return nil
}
