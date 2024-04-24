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
	cwd := os.Getenv("BUILD_WORKING_DIRECTORY")
	err = runProcess(args, env, cwd)
	if err != nil {
		log.Fatal(err)
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
			_, _ = fmt.Fprintf(os.Stderr, "\nrules_go: Running '%s mod tidy' since %s changed...\n", bazel, strings.Join(diff, ", "))
			err = runProcess([]string{bazel, "mod", "tidy"}, os.Environ(), cwd)
			if err != nil {
				log.Fatal(err)
			}
		} else {
			_, _ = fmt.Fprintf(os.Stderr, "\nrules_go: %s changed, please apply any buildozer fixes suggested by Bazel\n", strings.Join(diff, ", "))
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

func hashWorkspaceRelativeFiles(relativePaths []string) (map[string]string, error) {
	workspace := os.Getenv("BUILD_WORKSPACE_DIRECTORY")

	hashes := make(map[string]string)
	for _, p := range relativePaths {
		h, err := hashFile(filepath.Join(workspace, p))
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

func runProcess(args, env []string, dir string) error {
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Dir = dir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = env
	err := cmd.Run()
	if exitErr, ok := err.(*exec.ExitError); ok {
		os.Exit(exitErr.ExitCode())
	}
	return err
}
