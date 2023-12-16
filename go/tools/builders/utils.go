// Copyright 2017 The Bazel Authors. All rights reserved.
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

package main

import (
	"io"
	"os"
	"path/filepath"
	"runtime"
)

func copyFile(inPath, outPath string) error {
	inFile, err := os.Open(inPath)
	if err != nil {
		return err
	}
	defer inFile.Close()
	outFile, err := os.OpenFile(outPath, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0666)
	if err != nil {
		return err
	}
	defer outFile.Close()
	_, err = io.Copy(outFile, inFile)
	return err
}

func linkFile(inPath, outPath string) error {
	inPath, err := filepath.Abs(inPath)
	if err != nil {
		return err
	}
	return os.Symlink(inPath, outPath)
}

func copyOrLinkFile(inPath, outPath string) error {
	if runtime.GOOS == "windows" {
		return copyFile(inPath, outPath)
	} else {
		return linkFile(inPath, outPath)
	}
}
