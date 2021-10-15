// Copyright 2021 The Bazel Authors. All rights reserved.
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
	"context"
	"errors"
)

func checkNoGitChanges(ctx context.Context, dir string) error {
	out, err := runForOutput(ctx, dir, "git", "status", "--porcelain", "--untracked-files=no")
	if err != nil {
		return err
	}
	if len(out) > 0 {
		return errors.New("Repository has pending changes. Commit them and try again.")
	}
	return nil
}

func gitBranchExists(ctx context.Context, dir, branchName string) bool {
	err := runForError(ctx, dir, "git", "show-ref", "--verify", "--quiet", "refs/heads/"+branchName)
	return err == nil
}

func gitCreateBranch(ctx context.Context, dir, branchName, refName string) error {
	return runForError(ctx, dir, "git", "branch", branchName, refName)
}

func gitPushBranch(ctx context.Context, dir, branchName string) error {
	return runForError(ctx, dir, "git", "push", "origin", branchName)
}

func gitCreateArchive(ctx context.Context, dir, branchName, arcName string) error {
	return runForError(ctx, dir, "git", "archive", "--output="+arcName, branchName)
}

func gitCatFile(ctx context.Context, dir, refName, fileName string) ([]byte, error) {
	return runForOutput(ctx, dir, "git", "cat-file", "blob", refName+":"+fileName)
}
