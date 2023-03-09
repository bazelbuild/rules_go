package main

import (
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

var GoBinRlocationPath = "not set"

func main() {
	goBin, err := runfiles.Rlocation(GoBinRlocationPath)
	if err != nil {
		log.Fatal(err)
	}
	// The go binary lies at $GOROOT/bin/go.
	goRoot, err := filepath.Abs(filepath.Dir(filepath.Dir(goBin)))
	if err != nil {
		log.Fatal(err)
	}

	env := os.Environ()
	var filteredEnv []string
	for i := 0; i < len(env); i++ {
		if !strings.HasPrefix(env[i], "GOROOT=") {
			filteredEnv = append(filteredEnv, env[i])
		}
	}
	filteredEnv = append(filteredEnv, "GOROOT="+goRoot)

	err = os.Chdir(os.Getenv("BUILD_WORKING_DIRECTORY"))
	if err != nil {
		log.Fatal(err)
	}

	args := append([]string{goBin}, os.Args[1:]...)
	log.Fatal(ReplaceWithProcess(args, filteredEnv))
}
