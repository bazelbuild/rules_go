package main

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
)

func cc(args []string) error {
	cc := os.Getenv("GO_CC")
	if cc == "" {
		errors.New("GO_CC environment variable not set")
	}
	ccroot := os.Getenv("GO_CC_ROOT")
	if ccroot == "" {
		errors.New("GO_CC_ROOT environment variable not set")
	}
	normalized := []string{cc}
	normalized = append(normalized, args...)
	transformArgs(normalized, cgoAbsEnvFlags, func(s string) string {
		if strings.HasPrefix(s, cgoAbsPlaceholder) {
			trimmed := strings.TrimPrefix(s, cgoAbsPlaceholder)
			abspath := filepath.Join(ccroot, trimmed)
			if _, err := os.Stat(abspath); err == nil {
				return abspath
			}
			return trimmed
		}
		return s
	})
	if runtime.GOOS == "windows" {
		cmd := exec.Command(normalized[0], normalized[1:]...)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		return cmd.Run()
	} else {
		return syscall.Exec(normalized[0], normalized, os.Environ())
	}
}
