// Copyright 2018 The Bazel Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package bazel

import (
	"errors"
	"os"
)

const (
	RUNFILES_MANIFEST_FILE = "RUNFILES_MANIFEST_FILE"
	RUNFILES_DIR           = "RUNFILES_DIR"
)

var errNoRunfilesEnv = errors.New("runfiles environment missing")

// runfilesResolver is an interface for a resolver that can take a runfiles path and resolve it to a path on
// disk.
type runfilesResolver interface {
	Resolve(string) (string, bool)
}

// newRunfilesResolver creates a new runfiles resolver. The type of resolver and its parameters are derived
// from the environment.
func newRunfilesResolver() (runfilesResolver, error) {
	manifest := os.Getenv(RUNFILES_MANIFEST_FILE)
	if manifest != "" {
		f, err := os.Open(manifest)
		if err != nil {
			return nil, err
		}
		defer f.Close()
		return newManifestRunfilesResolver(f)
	}

	directory := os.Getenv(RUNFILES_DIR)
	if directory != "" {
		return newDirectoryRunfilesResolver(directory)
	}

	return nil, errNoRunfilesEnv
}
