package transitive_data

import (
	"os"
	"testing"
)

func TestFiles(t *testing.T) {
	filenames := os.Args[1:]
	if len(filenames) == 0 {
		t.Fatal("no filenames given")
	}

	for _, filename := range os.Args[1:] {
		if _, err := os.Stat(filename); err != nil {
			t.Error(err)
		}
	}
}
