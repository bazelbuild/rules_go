// Copyright 2020 The Bazel Authors. All rights reserved.
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

package bzltestutil

import (
	"fmt"
	"os"
	"testing"
)

func TestShouldWrap(t *testing.T) {
	var tests = []struct {
		envs       map[string]string
		shouldWrap bool
	}{
		{
			envs: map[string]string{
				"GO_TEST_WRAP":    "0",
				"XML_OUTPUT_FILE": "",
			},
			shouldWrap: false,
		}, {
			envs: map[string]string{
				"GO_TEST_WRAP":    "1",
				"XML_OUTPUT_FILE": "",
			},
			shouldWrap: true,
		}, {
			envs: map[string]string{
				"GO_TEST_WRAP":    "",
				"XML_OUTPUT_FILE": "path",
			},
			shouldWrap: true,
		},
	}
	for _, tt := range tests {
		t.Run(fmt.Sprintf("%v", tt.envs), func(t *testing.T) {
			for k, v := range tt.envs {
				if v == "" {
					os.Unsetenv(k)
				} else {
					os.Setenv(k, v)
				}
			}
			got := ShouldWrap()
			if tt.shouldWrap != got {
				t.Errorf("shouldWrap returned %t, expected %t", got, tt.shouldWrap)
			}
		})
	}
}
