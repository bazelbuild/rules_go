package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path/filepath"

	"gopkg.in/yaml.v2"
)

func main() {
	log.SetFlags(0)
	log.SetPrefix("testrunner: ")

	var configPath string
	flag.StringVar(&configPath, "config", "", "location of presubmit.yml")
	flag.Parse()
	if configPath == "" {
		var err error
		configPath, err = findConfigPath()
		if err != nil {
			log.Fatal(err)
		}
	}

	if err := run(configPath, flag.Args()); err != nil {
		log.Fatal(err)
	}
}

func run(configPath string, args []string) error {
	configData, err := ioutil.ReadFile(configPath)
	if err != nil {
		return err
	}
	var config interface{}
	if err := yaml.Unmarshal(configData, &config); err != nil {
		return err
	}

	platform := config.(map[interface{}]interface{})["platforms"].(map[interface{}]interface{})["windows"].(map[interface{}]interface{})
	var buildFlags []string
	for _, f := range platform["build_flags"].([]interface{}) {
		buildFlags = append(buildFlags, f.(string))
	}
	testFlags := buildFlags
	for _, f := range platform["test_flags"].([]interface{}) {
		testFlags = append(testFlags, f.(string))
	}
	var buildTargets, testTargets []string
	if len(args) == 0 {
		for _, t := range platform["build_targets"].([]interface{}) {
			buildTargets = append(buildTargets, t.(string))
		}
		for _, t := range platform["test_targets"].([]interface{}) {
			testTargets = append(testTargets, t.(string))
		}
	} else {
		buildTargets = args
		testTargets = args
	}

	buildCmd := exec.Command("bazel", "build")
	buildCmd.Args = append(buildCmd.Args, buildFlags...)
	buildCmd.Args = append(buildCmd.Args, buildTargets...)
	buildCmd.Stdout = os.Stdout
	buildCmd.Stderr = os.Stderr
	if err := buildCmd.Run(); err != nil {
		return err
	}

	testCmd := exec.Command("bazel", "test")
	testCmd.Args = append(testCmd.Args, testFlags...)
	testCmd.Args = append(testCmd.Args, testTargets...)
	testCmd.Stdout = os.Stdout
	testCmd.Stderr = os.Stderr
	if err := testCmd.Run(); err != nil {
		return err
	}

	return nil
}

func findConfigPath() (string, error) {
	d, err := os.Getwd()
	if err != nil {
		return "", err
	}
	for {
		configPath := filepath.Join(d, ".bazelci/presubmit.yml")
		_, err := os.Stat(configPath)
		if !os.IsNotExist(err) {
			return configPath, nil
		}
		parent := filepath.Dir(d)
		if parent == d {
			return "", fmt.Errorf("could not find presubmit.yml")
		}
		d = parent
	}
}
