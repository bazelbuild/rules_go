// Copyright 2021 The Bazel Authors. All rights reserved.
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

package protocol

import (
	"go/types"

	"golang.org/x/tools/go/packages"
)

// Request is a JSON object sent by golang.org/x/tools/go/packages
// on stdin. Keep in sync.
type Request struct {
	Mode packages.LoadMode `json:"mode"`
	// Env specifies the environment the underlying build system should be run in.
	Env []string `json:"env"`
	// BuildFlags are flags that should be passed to the underlying build system.
	BuildFlags []string `json:"build_flags"`
	// Tests specifies whether the patterns should also return test packages.
	Tests bool `json:"tests"`
	// Overlay maps file paths (relative to the driver's working directory) to the byte contents
	// of overlay files.
	Overlay map[string][]byte `json:"overlay"`
}

// Response is a JSON object sent by this program to
// golang.org/x/tools/go/packages on stdout. Keep in sync.
type Response struct {
	// NotHandled is returned if the request can't be handled by the current
	// driver. If an external driver returns a response with NotHandled, the
	// rest of the driverResponse is ignored, and go/packages will fallback
	// to the next driver. If go/packages is extended in the future to support
	// lists of multiple drivers, go/packages will fall back to the next driver.
	NotHandled bool

	// Sizes, if not nil, is the types.Sizes to use when type checking.
	Sizes *types.StdSizes

	// Roots is the set of package IDs that make up the root packages.
	// We have to encode this separately because when we encode a single package
	// we cannot know if it is one of the roots as that requires knowledge of the
	// graph it is part of.
	Roots []string `json:",omitempty"`

	// Packages is the full set of packages in the graph.
	// The packages are not connected into a graph.
	// The Imports if populated will be stubs that only have their ID set.
	// Imports will be connected and then type and syntax information added in a
	// later pass (see refine).
	Packages []*packages.Package
}
