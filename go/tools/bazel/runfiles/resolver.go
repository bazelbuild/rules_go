// Copyright 2018 Google Inc.
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

package runfiles

import (
	"errors"
	"os"
)

const (
	RUNFILES_MANIFEST_FILE = "RUNFILES_MANIFEST_FILE"
	RUNFILES_DIR           = "RUNFILES_DIR"
)

// These are the possible Runfiles-related errors.
var (
	ErrNoRunfilesEnv   = errors.New("runfiles environment missing")
	ErrManifestInvalid = errors.New("runfiles manifest syntax error")
)

// Resolver is an interface for a resolver that can take a runfiles path and
// resolve it to a path on disk.
type Resolver interface {
	Resolve(string) (string, error)
}

// NewResolver creates a new runfiles resolver. The type of resolver and its
// parameters are derived from the environment.
func NewResolver() (Resolver, error) {
	return newResolverWithGetenv(os.Getenv)
}

func newResolverWithGetenv(getenv func(string) string) (Resolver, error) {
	manifest := getenv(RUNFILES_MANIFEST_FILE)
	if manifest != "" {
		f, err := os.Open(manifest)
		if err != nil {
			return nil, err
		}
		return NewManifestResolver(f)
	}

	directory := getenv(RUNFILES_DIR)
	if directory != "" {
		return NewDirectoryResolver(directory)
	}

	return nil, ErrNoRunfilesEnv
}
