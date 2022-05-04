package analyzer

import "testing"

func TestHelloWorld(t *testing.T) {
	if name != Analyzer.Name {
		t.Errorf("want %s, got %s", name, Analyzer.Name)
	}
}
