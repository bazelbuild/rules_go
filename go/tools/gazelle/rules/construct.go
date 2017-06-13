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

	bzl "github.com/bazelbuild/buildtools/build"
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

func newRule(kind string, args []interface{}, kwargs []keyvalue) *bzl.Rule {
	var list []bzl.Expr
	for _, arg := range args {
		list = append(list, newValue(arg))
	}
	for _, arg := range kwargs {
		expr := newValue(arg.value)
		list = append(list, &bzl.BinaryExpr{
			X:  &bzl.LiteralExpr{Token: arg.key},
			Op: "=",
			Y:  expr,
		})
	}

	return &bzl.Rule{
		Call: &bzl.CallExpr{
			X:    &bzl.LiteralExpr{Token: kind},
			List: list,
		},
	}
}

// newValue converts a Go value into the corresponding expression in Bazel BUILD file.
func newValue(val interface{}) bzl.Expr {
	rv := reflect.ValueOf(val)
	switch rv.Kind() {
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64,
		reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		return &bzl.LiteralExpr{Token: fmt.Sprintf("%d", val)}

	case reflect.Float32, reflect.Float64:
		return &bzl.LiteralExpr{Token: fmt.Sprintf("%f", val)}

	case reflect.String:
		return &bzl.StringExpr{Value: val.(string)}

	case reflect.Slice, reflect.Array:
		var list []bzl.Expr
		for i := 0; i < rv.Len(); i++ {
			elem := newValue(rv.Index(i).Interface())
			list = append(list, elem)
		}
		return &bzl.ListExpr{List: list}

	case reflect.Map:
		rkeys := rv.MapKeys()
		sort.Sort(byString(rkeys))
		args := make([]bzl.Expr, len(rkeys))
		for i, rk := range rkeys {
			k := &bzl.StringExpr{Value: rk.String()}
			v := newValue(rv.MapIndex(rk).Interface())
			if l, ok := v.(*bzl.ListExpr); ok {
				l.ForceMultiLine = true
			}
			args[i] = &bzl.KeyValueExpr{Key: k, Value: v}
		}
		args = append(args, &bzl.KeyValueExpr{
			Key:   &bzl.StringExpr{Value: "//conditions:default"},
			Value: &bzl.ListExpr{},
		})
		sel := &bzl.CallExpr{
			X:    &bzl.LiteralExpr{Token: "select"},
			List: []bzl.Expr{&bzl.DictExpr{List: args, ForceMultiLine: true}},
		}
		return sel

	case reflect.Struct:
		switch val := val.(type) {
		case globvalue:
			patternsValue := newValue(val.patterns)
			globArgs := []bzl.Expr{patternsValue}
			if len(val.excludes) > 0 {
				excludesValue := newValue(val.excludes)
				globArgs = append(globArgs, &bzl.KeyValueExpr{
					Key:   &bzl.StringExpr{Value: "excludes"},
					Value: excludesValue,
				})
			}
			return &bzl.CallExpr{
				X:    &bzl.LiteralExpr{Token: "glob"},
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

			if genList, ok := gen.(*bzl.ListExpr); ok {
				genList.ForceMultiLine = true
			}
			return &bzl.BinaryExpr{X: gen, Op: "+", Y: sel}
		}
	}

	log.Panicf("type not supported: %T", val)
	return nil
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
