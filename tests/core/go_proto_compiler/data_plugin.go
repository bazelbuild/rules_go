package main

import (
	"flag"
	"strings"

	"google.golang.org/protobuf/compiler/protogen"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

var config []byte

func main() {
	var flags flag.FlagSet
	configPath := flags.String("config", "", "path to config")

	protogen.Options{ParamFunc: flags.Set}.Run(func(gen *protogen.Plugin) error {
		if *configPath == "" {
			panic("provide config path")
		}
		runfiles, err := runfiles.New()
		if err != nil {
			panic(err)
		}
		config, err = runfiles.ReadFile(*configPath)
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
