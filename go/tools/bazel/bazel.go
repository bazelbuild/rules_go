package bazel

import (
	"context"
	"errors"
	"os"
	"os/exec"
	"strings"
)

type Bazel struct {
	cmd           *exec.Cmd
	ctx           context.Context
	cancel        context.CancelFunc
	writeToStderr bool
	writeToStdout bool
}

func New() *Bazel {
	return &Bazel{}
}

// WriteToStderr when running an operation.
func (b *Bazel) WriteToStderr(v bool) {
	b.writeToStderr = v
}

// WriteToStdout when running an operation.
func (b *Bazel) WriteToStdout(v bool) {
	b.writeToStdout = v
}

func (b *Bazel) newCommand(command string, args ...string) {
	b.ctx, b.cancel = context.WithCancel(context.Background())

	args = append([]string{command}, args...)
	b.cmd = exec.CommandContext(b.ctx, "bazel", args...)
	if b.writeToStderr {
		b.cmd.Stderr = os.Stderr
	}
	if b.writeToStdout {
		b.cmd.Stdout = os.Stdout
	}
}

// Displays information about the state of the bazel process in the
// form of several "key: value" pairs.  This includes the locations of
// several output directories.  Because some of the
// values are affected by the options passed to 'bazel build', the
// info command accepts the same set of options.
//
// A single non-option argument may be specified (e.g. "bazel-bin"), in
// which case only the value for that key will be printed.
//
// The full list of keys and the meaning of their values is documented in
// the bazel User Manual, and can be programmatically obtained with
// 'bazel help info-keys'.
//
//   res, err := b.Info()
func (b *Bazel) Info() (map[string]string, error) {
	b.WriteToStderr(false)
	b.WriteToStdout(false)
	b.newCommand("info")

	info, err := b.cmd.Output()
	if err != nil {
		return nil, err
	}
	return b.processInfo(string(info))
}

func (b *Bazel) processInfo(info string) (map[string]string, error) {
	lines := strings.Split(info, "\n")
	output := make(map[string]string, 0)
	for _, line := range lines {
		if line == "" {
			continue
		}
		data := strings.SplitN(line, ": ", 2)
		if len(data) != 2 {
			return nil, errors.New("Bazel info returned a non key-value pair")
		}
		output[data[0]] = data[1]
	}
	return output, nil
}

// Executes a query language expression over a specified subgraph of the
// build dependency graph.
//
// For example, to show all C++ test rules in the strings package, use:
//
//   res, err := b.Query('kind("cc_.*test", strings:*)')
//
// or to find all dependencies of //path/to/package:target, use:
//
//   res, err := b.Query('deps(//path/to/package:target)')
//
// or to find a dependency path between //path/to/package:target and //dependency:
//
//   res, err := b.Query('somepath(//path/to/package:target, //dependency)')
func (b *Bazel) Query(args ...string) ([]string, error) {
	b.newCommand("query", args...)
	b.WriteToStderr(false)
	b.WriteToStdout(false)

	info, err := b.cmd.Output()
	if err != nil {
		return nil, err
	}
	return b.processQuery(string(info))
}

func (b *Bazel) processQuery(info string) ([]string, error) {
	toReturn := make([]string, 0, 10000)
	lines := strings.Split(info, "\n")
	for _, line := range lines {
		if line == "" {
			continue
		}
		toReturn = append(toReturn, line)
	}
	return toReturn, nil
}

func (b *Bazel) Build(args ...string) error {
	b.newCommand("build", args...)

	err := b.cmd.Run()

	return err
}

func (b *Bazel) Test(args ...string) error {
	b.newCommand("test", append([]string{"--test_output=streamed"}, args...)...)

	err := b.cmd.Run()

	return err
}

// Build the specified target (singular) and run it with the given arguments.
func (b *Bazel) Run(args ...string) (*exec.Cmd, error) {
	b.newCommand("run", args...)
	b.WriteToStderr(true)
	b.WriteToStdout(true)
	b.cmd.Stdin = os.Stdin

	err := b.cmd.Run()
	if err != nil {
		return nil, err
	}

	return b.cmd, err
}

// Cancel the currently running operation. Useful if you call Run(target) and
// would like to stop the action running in a goroutine.
func (b *Bazel) Cancel() {
	if b.cancel == nil {
		return
	}

	b.cancel()
}
