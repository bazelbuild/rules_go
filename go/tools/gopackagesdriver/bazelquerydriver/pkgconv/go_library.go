// Copyright 2021 The Bazel Go Rules Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package pkgconv

import (
	"log"
	"path/filepath"
	"strings"

	"golang.org/x/tools/go/packages"
)

func convertGoLibrary(t target, targets map[string]*target) []*packages.Package {
	if t.importpath == "" {
		log.Printf("no importpath for %v\n", t.name)
		return nil
	}

	pkg := &packages.Package{
		ID:      t.name,
		PkgPath: t.importpath,
		Imports: make(map[string]*packages.Package),
	}

	processGoSrcs(t, targets, pkg)
	processDeps(t, targets, pkg)

	// add in any embeds
	for _, e := range t.embed {
		if et := targets[e]; et != nil {
			if epkg := et.toPackage(targets); epkg != nil {
				pkg.GoFiles = append(pkg.GoFiles, epkg[0].GoFiles...)
				pkg.OtherFiles = append(pkg.OtherFiles, epkg[0].OtherFiles...)
				for k, v := range epkg[0].Imports {
					if pkg.Imports[k] == nil && v != nil {
						pkg.Imports[k] = v
					}
				}
			}
		} else {
			log.Printf("Unknown embed %v\n", e)
		}
	}

	if len(pkg.GoFiles)+len(pkg.OtherFiles) == 0 {
		log.Printf("no srcs for %v\n", t.name)
		return nil
	}

	return []*packages.Package{pkg}
}

func srcPath(t target, targets map[string]*target, src string) string {
	packagePrefix := t.name[:strings.Index(t.name, ":")+1]
	if generator, defined := targets[src]; defined {
		switch generator.rule {
		case "go_embed_data":
			return embedDataPath(*generator)
		default:
			log.Printf("Unhandled %v in srcs of %v: %v\n", generator.rule, t.name, generator.name)
			return ""
		}
	} else if strings.HasPrefix(src, packagePrefix) {
		return filepath.Join(t.folder, strings.TrimPrefix(src, packagePrefix))
	} else {
		log.Printf("Unrecognized entry in srcs of %v: %v\n", t.name, src)
		return ""
	}
}

func processGoSrcs(t target, targets map[string]*target, pkg *packages.Package) {
	for _, src := range t.srcs {
		path := srcPath(t, targets, src)
		if path != "" {
			switch filepath.Ext(path) {
			case ".go":
				pkg.GoFiles = append(pkg.GoFiles, path)
			default:
				pkg.OtherFiles = append(pkg.OtherFiles, path)
			}
		}
	}
}

func processDeps(t target, targets map[string]*target, pkg *packages.Package) {
	for _, depname := range t.deps {
		dep := targets[depname]
		for dep != nil && dep.rule == "alias" {
			dep = targets[dep.actual]
		}
		if dep != nil && (dep.rule == "go_library" || dep.rule == "go_proto_library") {
			pkg.Imports[dep.importpath] = &packages.Package{ID: dep.name}
		} else {
			log.Printf("%s: Unhandled dep %s", t.name, depname)
		}
	}
}
