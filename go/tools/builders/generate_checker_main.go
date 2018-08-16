/* Copyright 2018 The Bazel Authors. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// Generates a checker binary for Bazel Go rules.

package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"text/template"
)

var codeTpl = `
package main

import (
{{- range $importPath := .ImportPaths}}
	_ "{{$importPath}}"
{{- end}}
)

// configs maps analysis names to configurations.
var configs = map[string]config{
{{- range $name, $config := .Configs}}
	{{printf "%q" $name}}: config{
		{{- if $config.ApplyTo -}}
		applyTo:  map[string]bool{
			{{range $path, $comment := $config.ApplyTo -}}
			// {{$comment}}
			{{printf "%q" $path}}: true,
			{{- end}}
		},
		{{- end}}
		{{if $config.Whitelist -}}
		whitelist:  map[string]bool{
			{{range $path, $comment := $config.Whitelist -}}
			// {{$comment}}
			{{printf "%q" $path}}: true,
			{{- end}}
		},
		{{- end}}
	},
{{- end}}
}
`

func run(args []string) error {
	checkImportPaths := multiFlag{}
	flags := flag.NewFlagSet("generate_checker_main", flag.ExitOnError)
	out := flags.String("output", "", "output file to write (defaults to stdout)")
	flags.Var(&checkImportPaths, "check_importpath", "import path of a check library")
	configFile := flags.String("config", "", "checker config file")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *out == "" {
		return errors.New("must provide output file")
	}

	outFile := os.Stdout
	var cErr error
	outFile, err := os.Create(*out)
	if err != nil {
		return fmt.Errorf("os.Create(%q): %v", *out, err)
	}
	defer func() {
		if err := outFile.Close(); err != nil {
			cErr = fmt.Errorf("error closing %s: %v", outFile.Name(), err)
		}
	}()

	config, err := buildConfig(*configFile)
	if err != nil {
		return err
	}
	data := struct {
		ImportPaths []string
		Configs     Configs
	}{
		ImportPaths: checkImportPaths,
		Configs:     config,
	}
	tpl := template.Must(template.New("source").Parse(codeTpl))
	if err := tpl.Execute(outFile, data); err != nil {
		return fmt.Errorf("template.Execute failed: %v", err)
	}
	return cErr
}

func main() {
	if err := run(os.Args[1:]); err != nil {
		log.Fatal(err)
	}
}

func buildConfig(path string) (Configs, error) {
	if path == "" {
		return Configs{}, nil
	}
	b, err := ioutil.ReadFile(path)
	if err != nil {
		return Configs{}, fmt.Errorf("failed to read config file: %v", err)
	}
	configs := make(Configs)
	if err = json.Unmarshal(b, &configs); err != nil {
		return Configs{}, fmt.Errorf("failed to unmarshal config file: %v", err)
	}
	for name, config := range configs {
		configs[name] = Config{
			// Description is currently unused.
			ApplyTo:   config.ApplyTo,
			Whitelist: config.Whitelist,
		}
	}
	return configs, nil
}

type Configs map[string]Config

type Config struct {
	Description string
	ApplyTo     map[string]string `json:"apply_to"`
	Whitelist   map[string]string
}
