// Package wspace provides functions to locate and modify a bazel WORKSPACE file.
package wspace

import (
	"os"
	"path/filepath"
)

const workspaceFile = "WORKSPACE"

// Find searches from the given dir and up for the WORKSPACE file
// returning the directory containing it, or an error if none found in the tree.
func Find(dir string) (string, error) {
	if dir == "" || dir == "/" {
		return "", os.ErrNotExist
	}
	_, err := os.Stat(filepath.Join(dir, workspaceFile))
	if err == nil {
		return dir, nil
	}
	if !os.IsNotExist(err) {
		return "", err
	}
	return Find(filepath.Dir(dir))
}
