package main

import (
	"os"
	"os/exec"
)

func ReplaceWithProcess(args, env []string) error {
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = env
	err := cmd.Run()
	if exitErr, ok := err.(*exec.ExitError); ok {
		os.Exit(exitErr.ExitCode())
	} else if err == nil {
		os.Exit(0)
	}
	return err
}
