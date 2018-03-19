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

package embed_test

import (
	"testing"

	"github.com/bazelbuild/rules_go/tests/core/go_proto_library/foo"
	"github.com/golang/protobuf/proto"
)

func TestProto(t *testing.T) {
	x := foo.Foo{Value: 42}
	data, err := proto.Marshal(&x)
	if err != nil {
		t.Fatal(err)
	}
	var y foo.Foo
	err = proto.Unmarshal(data, &y)
	if err != nil {
		t.Fatal(err)
	}
	if y.Value != x.Value {
		t.Errorf("got {x = %d}; want {x = %d}", y.Value, x.Value)
	}
}

func TestExtra(t *testing.T) {
	if got, want := foo.Extra(), 42; got != want {
		t.Errorf("got %d; want %d", got, want)
	}
}
