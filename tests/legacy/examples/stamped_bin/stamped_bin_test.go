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

package stamped_bin_test

import (
	"testing"

	"github.com/bazelbuild/rules_go/examples/stamped_bin/stamp"
)

func TestStampedBin(t *testing.T) {
	// If we use an x_def when linking to override BUILD_TIMESTAMP but fail to
	// pass through the workspace status value, it'll be set to empty string -
	// overridden but still wrong. Check for that case too.
	if stamp.BUILD_TIMESTAMP == stamp.NOT_A_TIMESTAMP || stamp.BUILD_TIMESTAMP == "" {
		t.Errorf("Expected timestamp to have been modified, got %s.", stamp.BUILD_TIMESTAMP)
	}
	if stamp.XdefBuildTimestamp == "" {
		t.Errorf("Expected XdefBuildTimestamp to have been modified, got %s.", stamp.XdefBuildTimestamp)
	}
	if stamp.PassIfEmpty != "" {
		t.Errorf("Expected PassIfEmpty to have been set to '', got %s.", stamp.PassIfEmpty)
	}
	if stamp.XdefInvalid != "pass" {
		t.Errorf("Expected XdefInvalid to have been left alone, got %s.", stamp.XdefInvalid)
	}
}
