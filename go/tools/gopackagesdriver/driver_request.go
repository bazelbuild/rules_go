package main

import (
	"encoding/json"
	"io"

	"golang.org/x/tools/go/packages"
)

type DriverRequest struct {
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

func ReadDriverRequest(r io.Reader) (*DriverRequest, error) {
	req := &DriverRequest{}
	if err := json.NewDecoder(r).Decode(&req); err != nil {
		return nil, err
	}
	return req, nil
}
