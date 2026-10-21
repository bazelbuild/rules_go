// Copyright 2026 The Bazel Authors. All rights reserved.
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

package main

import (
	"bytes"
	"io"
	"testing"
	"testing/iotest"
)

func TestIndexReader(t *testing.T) {
	pattern := []byte(goBuildPrefix + buildIDPlaceholder + goBuildEnd)
	data := make([]byte, 2*indexReaderBufSize)

	// Place the pattern around the buffer boundary, where matches can straddle two reads.
	for off := indexReaderBufSize - 2*len(pattern); off <= indexReaderBufSize+2*len(pattern); off++ {
		copy(data[off:], pattern)
		for name, r := range map[string]io.Reader{
			"full": bytes.NewReader(data),
			"half": iotest.HalfReader(bytes.NewReader(data)),
		} {
			if got := index(t, r, pattern); got != int64(off) {
				t.Fatalf("%s reader, pattern at %d: got %d", name, off, got)
			}
		}
		copy(data[off:], make([]byte, len(pattern)))
	}

	copy(data[len(data)-len(pattern):], pattern)
	if got := index(t, bytes.NewReader(data), pattern); got != int64(len(data)-len(pattern)) {
		t.Errorf("pattern at the end: got %d", got)
	}
	if got := index(t, bytes.NewReader(data[:len(data)-1]), pattern); got != -1 {
		t.Errorf("truncated pattern: got %d, want -1", got)
	}
	if got := index(t, bytes.NewReader(nil), pattern); got != -1 {
		t.Errorf("empty input: got %d, want -1", got)
	}
}

func index(t *testing.T, r io.Reader, pattern []byte) int64 {
	t.Helper()
	i, err := indexReader(r, pattern)
	if err != nil {
		t.Fatal(err)
	}
	return i
}
