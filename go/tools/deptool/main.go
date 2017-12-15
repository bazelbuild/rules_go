/*
deptool generates vendor.bzl file base on Gopkg.lock.
Gopkg.lock can be generated with:
  dep ensure -no-vendor

Example Usage:
  deptool -lock Gopkg.lock -vendor vendor.bzl

In WORKSPACE add this:
  load("//:vendor.bzl", "vendor_install")
  vendor_install()
*/
package main

import (
	"flag"
	"log"
	"os"
	"strings"
	"text/template"

	"github.com/pelletier/go-toml"
)

const (
	vendorTmpl = `# Install Go vendored libs
#
# Generated from Gopkg.lock
load("@io_bazel_rules_go//go:def.bzl", "go_repository")

def vendor_install():
{{range .Projects}}{{$repo := repoName .Name}}
  if "{{$repo}}" not in native.existing_rules():
    go_repository(
        name = "{{$repo}}",
        importpath = "{{.Name}}",
        commit = "{{.Revision}}",
    )
{{end}}
`
)

type rawLock struct {
	Projects []rawLockedProject `toml:"projects"`
}

type rawLockedProject struct {
	Name     string `toml:"name"`
	Revision string `toml:"revision"`
}

func repoName(importpath string) string {
	components := strings.Split(importpath, "/")
	labels := strings.Split(components[0], ".")
	var reversed []string
	for i := range labels {
		l := labels[len(labels)-i-1]
		reversed = append(reversed, l)
	}
	repo := strings.Join(append(reversed, components[1:]...), "_")
	return strings.NewReplacer("-", "_", ".", "_").Replace(repo)
}

func main() {
	var lockPath string
	var vendor string
	flag.StringVar(&lockPath, "lock", "Gopkg.lock", "Gopkg.lock file")
	flag.StringVar(&vendor, "vendor", "vendor.bzl", "vendor.bzl file")
	flag.Parse()

	tree, err := toml.LoadFile(lockPath)
	if err != nil {
		log.Fatal(err)
	}

	var lock rawLock
	err = tree.Unmarshal(&lock)
	if err != nil {
		log.Fatal(err)
	}

	output, err := os.Create(vendor)
	if err != nil {
		log.Fatal(err)
	}
	defer output.Close()

	funcs := template.FuncMap{
		"repoName": repoName,
	}

	tmpl := template.Must(template.New("vendor").Funcs(funcs).Parse(vendorTmpl))
	if err := tmpl.Execute(output, lock); err != nil {
		log.Fatal(err)
	}
}
