package data

import (
	"testing"
)

func TestReadFile(t *testing.T) {
	_, err := readFile()
	if err != nil {
		t.Fatalf("Unable to read file cause: %v", err)
	}
}
