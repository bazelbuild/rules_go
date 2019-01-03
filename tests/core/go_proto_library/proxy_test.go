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

package proxy_test

import (
	"testing"

	"github.com/bazelbuild/rules_go/tests/core/go_proto_library/proxy"
)

func use(interface{}) {}

func TestProxy(t *testing.T) {
	// just make sure both types exist
	use(proxy.A{})
	use(proxy.B{})
}
