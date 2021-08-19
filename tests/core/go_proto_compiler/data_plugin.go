package main

import (
	"flag"
	"io/ioutil"
	"strings"

	"github.com/bazelbuild/rules_go/go/tools/bazel"
	"google.golang.org/protobuf/compiler/protogen"
)

var config []byte

func main() {
	var flags flag.FlagSet
	configPath := flags.String("config", "", "path to config")

	protogen.Options{ParamFunc: flags.Set}.Run(func(gen *protogen.Plugin) error {
		if *configPath == "" {
			panic("provide config path")
		}
		path, err := bazel.Runfile(*configPath)
		if err != nil {
			panic(err)
		}
		config, err = ioutil.ReadFile(path)
		if err != nil {
			panic(err)
		}

		for _, f := range gen.Files {
			if f.Generate {
				filename := f.GeneratedFilenamePrefix + ".data.pb.go"
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
		g.P("const ", msg.GoIdent.GoName, "_greeting2 = `", greeting, "`")
	}
}
