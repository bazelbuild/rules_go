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

package cgolibwithtags

/**
#cgo CFLAGS: -I/weird/path
#cgo linux CFLAGS: -DGOOS=linux
#cgo darwin CFLAGS: -DGOOS=darwin
#cgo windows CFLAGS: -DGOOS=windows
#cgo LDFLAGS: -lweird
**/
import "C"
import "fmt"

import "example.com/repo/lib"

func CCall() int64 {
	// Just for the lib import
	fmt.Println(lib.Answer())
	return C.callC()
}
