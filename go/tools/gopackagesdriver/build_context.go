package main

import (
	"go/build"
	"os"
	"path/filepath"
	"strings"
)

var buildContext = makeBuildContext()

func makeBuildContext() *build.Context {
	bctx := &build.Context{
		GOOS:        getenvDefault("GOOS", build.Default.GOOS),
		GOARCH:      getenvDefault("GOARCH", build.Default.GOARCH),
		GOROOT:      getenvDefault("GOROOT", build.Default.GOROOT),
		GOPATH:      getenvDefault("GOPATH", build.Default.GOPATH),
		BuildTags:   strings.Split(getenvDefault("GOTAGS", ""), ","),
		ReleaseTags: build.Default.ReleaseTags[:],
	}
	if v, ok := os.LookupEnv("CGO_ENABLED"); ok {
		bctx.CgoEnabled = v == "1"
	} else {
		bctx.CgoEnabled = build.Default.CgoEnabled
	}
	return bctx
}

func filterSourceFilesForTags(files []string) []string {
	ret := make([]string, 0, len(files))
	for _, f := range files {
		dir, filename := filepath.Split(f)
		if match, _ := buildContext.MatchFile(dir, filename); match {
			ret = append(ret, f)
		}
	}
	return ret
}
