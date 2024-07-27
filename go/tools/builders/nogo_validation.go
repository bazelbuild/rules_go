package main

import (
	"errors"
	"os"
)

func nogoValidation(args []string) error {
	validationOutput := args[0]
	logFile := args[1]
	// Always create the output file and only fail if the log file is non-empty to
	// avoid an "action failed to create outputs" error.
	logContent, err := os.ReadFile(logFile);
	if err != nil {
		return err
	}
	err := os.WriteFile(validationOutput, logContent)
	if err != nil {
		return err
	}
	if len(logContent) > 0 {
		// Separate nogo output from Bazel's --sandbox_debug message via an
		// empty line.
		return errors.New("\n" + string(logContent))
	}
	return nil
}
