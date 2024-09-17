package language_version_test

import "testing"

func TestLanguageVersion(t *testing.T) {
	// Verify that the language version is set to 1.21 by checking that for
	// loop variable semantics have *not* been changed.
	// https://github.com/golang/go/discussions/56010
	strings := []string{"foo", "bar"}
	var stringRefs []*string
	for _, s := range strings {
		stringRefs = append(stringRefs, &s)
	}
	if *stringRefs[0] != "bar" {
		t.Errorf("Expected bar, got %s", *stringRefs[0])
	}
}
