package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

var GoBinRlocationPath = "not set"
var ConfigRlocationPath = "not set"
var HasBazelModTidy = "not set"

var bazelWorkingDir = os.Getenv("BUILD_WORKSPACE_DIRECTORY")
var bazelWorkspaceDir = os.Getenv("BUILD_WORKSPACE_DIRECTORY")

// Produced by gazelle's go_deps extension.
type Config struct {
	GoEnv     map[string]string `json:"go_env"`
	DepsFiles []string          `json:"dep_files"`
}

func main() {
	goBin, err := runfiles.Rlocation(GoBinRlocationPath)
	if err != nil {
		log.Fatal(err)
	}

	cfg, err := parseConfig()
	if err != nil {
		log.Fatal(err)
	}

	env, err := getGoEnv(goBin, cfg)
	if err != nil {
		log.Fatal(err)
	}

	hashesBefore, err := hashWorkspaceRelativeFiles(cfg.DepsFiles)
	if err != nil {
		log.Fatal(err)
	}

	args := append([]string{goBin}, os.Args[1:]...)
	if err = runProcess(args, env); err != nil {
		log.Fatal(err)
	}

	if len(os.Args) > 1 && os.Args[1] == "get" {
		if err = markRequiresAsDirect(goBin, os.Args[2:]); err != nil {
			log.Fatal(err)
		}
	}

	hashesAfter, err := hashWorkspaceRelativeFiles(cfg.DepsFiles)
	if err != nil {
		log.Fatal(err)
	}

	diff := diffMaps(hashesBefore, hashesAfter)
	if len(diff) > 0 {
		if HasBazelModTidy == "True" {
			bazel := os.Getenv("BAZEL")
			if bazel == "" {
				bazel = "bazel"
			}
			_, _ = fmt.Fprintf(os.Stderr, "rules_go: Running '%s mod tidy' since %s changed...\n", bazel, strings.Join(diff, ", "))
			if err = runProcess([]string{bazel, "mod", "tidy"}, nil); err != nil {
				log.Fatal(err)
			}
		} else {
			_, _ = fmt.Fprintf(os.Stderr, "rules_go: %s changed, please apply any buildozer fixes suggested by Bazel\n", strings.Join(diff, ", "))
		}
	}
}

func parseConfig() (Config, error) {
	var cfg *Config
	// Special value set when rules_go is loaded as a WORKSPACE repo, in which
	// the cfg file isn't available from Gazelle.
	if ConfigRlocationPath == "WORKSPACE" {
		return Config{}, nil
	}
	cfgJsonPath, err := runfiles.Rlocation(ConfigRlocationPath)
	if err != nil {
		return Config{}, err
	}
	cfgJson, err := os.ReadFile(cfgJsonPath)
	if err != nil {
		return Config{}, err
	}
	err = json.Unmarshal(cfgJson, &cfg)
	if err != nil {
		return Config{}, err
	}
	return *cfg, nil
}

func getGoEnv(goBin string, cfg Config) ([]string, error) {
	env := os.Environ()
	for k, v := range cfg.GoEnv {
		env = append(env, k+"="+v)
	}

	// The go binary lies at $GOROOT/bin/go.
	goRoot, err := filepath.Abs(filepath.Dir(filepath.Dir(goBin)))
	if err != nil {
		return nil, err
	}

	// Override GOROOT to point to the hermetic Go SDK.
	return append(env, "GOROOT="+goRoot), nil
}

// Make every explicitly specified module a direct dep by removing the
// "// indirect" comment. This results in the go_deps extension treating the
// new module as visible to the main module, without the user having to first
// add a reference in code and run `go mod tidy`.
// https://github.com/golang/go/issues/68593
func markRequiresAsDirect(goBin string, getArgs []string) error {
	var pkgs []string
	for _, arg := range getArgs {
		if strings.HasPrefix(arg, "-") {
			// Skip flags.
			continue
		}
		pkgs = append(pkgs, strings.Split(arg, "@")[0])
	}

	// Run 'go mod edit -json' to get the list of requires.
	cmd := exec.Command(goBin, "mod", "edit", "-json")
	cmd.Dir = bazelWorkingDir
	out, err := cmd.Output()
	if err != nil {
		return err
	}

	var modJson struct {
		Require []struct{
			Path     string
			Version  string
			Indirect bool
		}
	}
	if err = json.Unmarshal(out, &modJson); err != nil {
		return err
	}

	// Make every explicitly specified module a direct dep by dropping and
	// re-adding the require directive - this is the only way to remove the
	// indirect comment with go mod edit.
	// Note that we do not use golang.org/x/mod/modfile to edit the go.mod file
	// as this would cause @rules_go//go to fail if there is an issue with this
	// module dep such as a missing sum.
	var editArgs []string
	for _, require := range modJson.Require {
		if !require.Indirect {
			continue
		}
		for _, pkg := range pkgs {
			if strings.HasPrefix(pkg, require.Path) && (len(pkg) == len(require.Path) || pkg[len(require.Path)] == '/') {
				editArgs = append(editArgs, "-droprequire", require.Path, "-require", require.Path+"@"+require.Version)
				break
			}
		}
	}

	if len(editArgs) > 0 {
		_, _ = fmt.Fprintln(os.Stderr, "rules_go: Marking requested modules as direct dependencies...")
		cmd = exec.Command(goBin, append([]string{"mod", "edit"}, editArgs...)...)
		cmd.Dir = bazelWorkingDir
		err = cmd.Run()
		if err != nil {
			return err
		}
	}

	return nil
}

func hashWorkspaceRelativeFiles(relativePaths []string) (map[string]string, error) {
	hashes := make(map[string]string)
	for _, p := range relativePaths {
		h, err := hashFile(filepath.Join(bazelWorkspaceDir, p))
		if err != nil {
			return nil, err
		}
		hashes[p] = h
	}
	return hashes, nil
}

// diffMaps returns the keys that have different values in a and b.
func diffMaps(a, b map[string]string) []string {
	var diff []string
	for k, v := range a {
		if b[k] != v {
			diff = append(diff, k)
		}
	}
	sort.Strings(diff)
	return diff
}

func hashFile(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

func runProcess(args, env []string) error {
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Dir = bazelWorkingDir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = env
	err := cmd.Run()
	if exitErr, ok := err.(*exec.ExitError); ok {
		os.Exit(exitErr.ExitCode())
	}
	return err
}
