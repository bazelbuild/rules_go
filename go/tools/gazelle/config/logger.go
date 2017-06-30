/* Copyright 2017 The Bazel Authors. All rights reserved.

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

package config

import "log"

// Logger is used to print possibly fatal errors.
//
// Each method is associated with a function field that tests may override.
// If the field is nil, the corresponding function in "log" will be called.
// Otherwise, the field will be called. This lets integration tests selectively
// override logging methods to check that errors are emitted.
//
// This should be used instead of log.Print and log.Fatal. log.Panic may still
// be used directly for situations that should "never happen". Tests do not
// check these.
type Logger struct {
	FatalFn  func(...interface{})
	FatalfFn func(string, ...interface{})
	PrintFn  func(...interface{})
	PrintfFn func(string, ...interface{})
}

func (l *Logger) Fatal(v ...interface{}) {
	if l.FatalFn != nil {
		l.FatalFn(v...)
	} else {
		log.Fatal(v...)
	}
}

func (l *Logger) Fatalf(format string, v ...interface{}) {
	if l.FatalfFn != nil {
		l.FatalfFn(format, v...)
	} else {
		log.Fatalf(format, v...)
	}
}

func (l *Logger) Print(v ...interface{}) {
	if l.PrintFn != nil {
		l.PrintFn(v...)
	} else {
		log.Print(v...)
	}
}

func (l *Logger) Printf(format string, v ...interface{}) {
	if l.PrintfFn != nil {
		l.PrintfFn(format, v...)
	} else {
		log.Printf(format, v...)
	}
}
