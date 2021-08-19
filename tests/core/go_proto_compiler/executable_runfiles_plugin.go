package main

import (
	"io/ioutil"
	"strings"

	"github.com/bazelbuild/rules_go/go/tools/bazel"
	"google.golang.org/protobuf/compiler/protogen"
)

var (
	configPath = "tests/core/go_proto_compiler/executable_runfiles.conf"
	config     []byte
)

func main() {
	path, err := bazel.Runfile(configPath)
	if err != nil {
		panic(err)
	}

	config, err = ioutil.ReadFile(path)
	if err != nil {
		panic(err)
	}

	protogen.Options{}.Run(func(gen *protogen.Plugin) error {
		for _, f := range gen.Files {
			if f.Generate {
				filename := f.GeneratedFilenamePrefix + ".executable_runfiles.pb.go"
				g := gen.NewGeneratedFile(filename, f.GoImportPath)
				generate(g, f)
			}
		}
		return nil
	})
}

func generate(g *protogen.GeneratedFile, f *protogen.File) {
	g.P("package ", f.GoPackageName)
	g.P()
	for _, msg := range f.Messages {
		greeting := strings.TrimSpace(string(config))
		g.P("const ", msg.GoIdent.GoName, `_greeting = "`, greeting, `"`)
	}
}
