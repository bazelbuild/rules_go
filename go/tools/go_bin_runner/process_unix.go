//go:build unix

package main

import (
	"golang.org/x/sys/unix"
)

func ReplaceWithProcess(args, env []string) error {
	return unix.Exec(args[0], args, env)
}
