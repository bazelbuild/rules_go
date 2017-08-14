/* Copyright 2016 The Bazel Authors. All rights reserved.

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

package rules

import (
	"fmt"
	"log"
	"reflect"
	"sort"

	bf "github.com/bazelbuild/buildtools/build"
	"github.com/bazelbuild/rules_go/go/tools/gazelle/packages"
)

type keyvalue struct {
	key   string
	value interface{}
}

type globvalue struct {
	patterns []string
	excludes []string
}

func newRule(kind string, args []interface{}, kwargs []keyvalue) *bf.CallExpr {
	sort.Sort(byAttrName(kwargs))

	var list []bf.Expr
	for _, arg := range args {
		list = append(list, newValue(arg))
	}
	for _, arg := range kwargs {
		expr := newValue(arg.value)
		list = append(list, &bf.BinaryExpr{
			X:  &bf.LiteralExpr{Token: arg.key},
			Op: "=",
			Y:  expr,
		})
	}

	return &bf.CallExpr{
		X:    &bf.LiteralExpr{Token: kind},
		List: list,
	}
}

// newValue converts a Go value into the corresponding expression in Bazel BUILD file.
func newValue(val interface{}) bf.Expr {
	rv := reflect.ValueOf(val)
	switch rv.Kind() {
	case reflect.Bool:
		tok := "False"
		if rv.Bool() {
			tok = "True"
		}
		return &bf.LiteralExpr{Token: tok}

	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64,
		reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		return &bf.LiteralExpr{Token: fmt.Sprintf("%d", val)}

	case reflect.Float32, reflect.Float64:
		return &bf.LiteralExpr{Token: fmt.Sprintf("%f", val)}

	case reflect.String:
		return &bf.StringExpr{Value: val.(string)}

	case reflect.Slice, reflect.Array:
		var list []bf.Expr
		for i := 0; i < rv.Len(); i++ {
			elem := newValue(rv.Index(i).Interface())
			list = append(list, elem)
		}
		return &bf.ListExpr{List: list}

	case reflect.Map:
		rkeys := rv.MapKeys()
		sort.Sort(byString(rkeys))
		args := make([]bf.Expr, len(rkeys))
		for i, rk := range rkeys {
			k := &bf.StringExpr{Value: rk.String()}
			v := newValue(rv.MapIndex(rk).Interface())
			if l, ok := v.(*bf.ListExpr); ok {
				l.ForceMultiLine = true
			}
			args[i] = &bf.KeyValueExpr{Key: k, Value: v}
		}
		args = append(args, &bf.KeyValueExpr{
			Key:   &bf.StringExpr{Value: "//conditions:default"},
			Value: &bf.ListExpr{},
		})
		sel := &bf.CallExpr{
			X:    &bf.LiteralExpr{Token: "select"},
			List: []bf.Expr{&bf.DictExpr{List: args, ForceMultiLine: true}},
		}
		return sel

	case reflect.Struct:
		switch val := val.(type) {
		case globvalue:
			patternsValue := newValue(val.patterns)
			globArgs := []bf.Expr{patternsValue}
			if len(val.excludes) > 0 {
				excludesValue := newValue(val.excludes)
				globArgs = append(globArgs, &bf.KeyValueExpr{
					Key:   &bf.StringExpr{Value: "excludes"},
					Value: excludesValue,
				})
			}
			return &bf.CallExpr{
				X:    &bf.LiteralExpr{Token: "glob"},
				List: globArgs,
			}

		case packages.PlatformStrings:
			gen := newValue(val.Generic)
			if len(val.Platform) == 0 {
				return gen
			}

			sel := newValue(val.Platform)
			if len(val.Generic) == 0 {
				return sel
			}

			if genList, ok := gen.(*bf.ListExpr); ok {
				genList.ForceMultiLine = true
			}
			return &bf.BinaryExpr{X: gen, Op: "+", Y: sel}
		}
	}

	log.Panicf("type not supported: %T", val)
	return nil
}

type byAttrName []keyvalue

var _ sort.Interface = byAttrName{}

func (s byAttrName) Len() int {
	return len(s)
}

// namePriority is the sort order for rule attributes.
// Copied from github.com/bazelbuild/buildifier/build/rewrite.go
var namePriority = map[string]int{
	"name":              -99,
	"gwt_name":          -98,
	"package_name":      -97,
	"visible_node_name": -96, // for boq_initial_css_modules and boq_jswire_test_suite
	"size":              -95,
	"timeout":           -94,
	"testonly":          -93,
	"src":               -92,
	"srcdir":            -91,
	"srcs":              -90,
	"out":               -89,
	"outs":              -88,
	"hdrs":              -87,
	"has_services":      -86, // before api versions, for proto
	"include":           -85, // before exclude, for glob
	"of":                -84, // for check_dependencies
	"baseline":          -83, // for searchbox_library
	// All others sort here, at 0.
	"destdir":        1,
	"exports":        2,
	"runtime_deps":   3,
	"deps":           4,
	"implementation": 5,
	"implements":     6,
	"alwayslink":     7,
}

func (s byAttrName) Less(i, j int) bool {
	if cmp := namePriority[s[i].key] - namePriority[s[j].key]; cmp != 0 {
		return cmp < 0
	}
	return s[i].key < s[j].key
}

func (s byAttrName) Swap(i, j int) {
	s[i], s[j] = s[j], s[i]
}

type byString []reflect.Value

var _ sort.Interface = byString{}

func (s byString) Len() int {
	return len(s)
}

func (s byString) Less(i, j int) bool {
	return s[i].String() < s[j].String()
}

func (s byString) Swap(i, j int) {
	s[i], s[j] = s[j], s[i]
}
