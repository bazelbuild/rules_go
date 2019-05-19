// Copyright 2019 The Bazel Authors. All rights reserved.
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

package import_alias

import (
	"import_alias/a"
	"import_alias/b"
	"testing"
)

func TestA(t *testing.T) {
	if a.A != "import_alias/a/v2" {
		t.Errorf("got %q; want %q", a.A, "import_alias/a/v2")
	}
}

func TestB(t *testing.T) {
	if b.B != "import_alias/b" {
		t.Errorf("got %q; want %q", b.B, "import_alias/b")
	}
}
