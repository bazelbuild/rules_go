// Copyright 2021 The Bazel Authors. All rights reserved.
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

func convertGoProtoLibrary(t target, targets map[string]*target) []*packages.Package {
	if t.importpath == "" {
		log.Printf("no importpath for %v\n", t.name)
		return nil
	}
	name := strings.SplitN(t.name, ":", 2)[1]
	path := filepath.Join(binpath(t.name), name+"_", t.importpath)

	pkg := &packages.Package{
		ID:      t.name,
		PkgPath: t.importpath,
		Imports: make(map[string]*packages.Package),
	}
	packagePrefix := t.name[:strings.Index(t.name, ":")+1]

	for _, proto := range t.srcs {
		for _, src := range protoSrcs(targets, proto) {
			basename := strings.TrimSuffix(filepath.Base(strings.TrimPrefix(src, packagePrefix)), ".proto")
			for _, cname := range t.compilers {
				if compiler := targets[cname]; compiler == nil {
					log.Printf("Unknown compiler %v\n", cname)
					continue
				} else if compiler.rule == "go_proto_wrapper" {
					if len(compiler.embed) == 0 || targets[compiler.embed[0]] == nil {
						log.Printf("invalid go_proto_wrapper %v", compiler.name)
						continue
					}
					lib := targets[compiler.embed[0]]
					libp := lib.toPackage(targets)
					if len(libp) == 0 {
						log.Printf("not found")
						continue
					}
					pkg.GoFiles = append(pkg.GoFiles, libp[0].GoFiles...)
					for k, v := range libp[0].Imports {
						pkg.Imports[k] = v
					}
				} else {
					pkg.GoFiles = append(pkg.GoFiles, filepath.Join(path, basename+compiler.suffix))
					t.deps = append(t.deps, compiler.deps...)
				}
			}
		}
	}

	processDeps(t, targets, pkg)

	return []*packages.Package{pkg}
}

func protoSrcs(targets map[string]*target, name string) []string {
	for targets[name] != nil && targets[name].rule == "alias" {
		log.Printf("%#v -> %#v", name, targets[name].actual)
		name = targets[name].actual
	}
	target := targets[name]
	if target == nil || target.rule != "proto_library" {
		log.Printf("Unrecognized proto_library  %#v\n", name)
		return nil
	}
	var srcs []string
	for _, s := range target.srcs {
		srcs = append(srcs, srcPath(*target, targets, s))
	}
	return srcs
}
