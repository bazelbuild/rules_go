package main

import (
	"encoding/json"
	"log"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

var GoBinRlocationPath = "not set"
var ConfigRlocationPath = "not set"

// Produced by gazelle's go_deps extension.
type Config struct {
	GoEnv map[string]string `json:"go_env"`
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

	args := append([]string{goBin}, os.Args[1:]...)
	log.Fatal(runProcess(args, env, os.Getenv("BUILD_WORKING_DIRECTORY")))
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

func runProcess(args, env []string, dir string) error {
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Dir = dir
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
