package bazel

import (
	"os"
	"reflect"
	"testing"
)

func TestNew(t *testing.T) {
	b := New()
	if b == nil {
		t.Fatalf("Created a nil object")
	}
}

func TestProcessInfo(t *testing.T) {
	b := New()
	got, err := b.processInfo(`KEY: VALUE
KEY2: VALUE2
KEY3: value`)
	if err != nil {
		t.Errorf("Error processing info", err)
	}

	expected := map[string]string{
		"KEY":  "VALUE",
		"KEY2": "VALUE2",
		"KEY3": "value",
	}

	if !reflect.DeepEqual(got, expected) {
		t.Errorf("Objects were inequal. Got:\n%s\nExpected:\n%s", got, expected)
	}
}

func TestWriteToStderrAndStdout(t *testing.T) {
	b := New()

	// By default it should write to its own pipe.
	b.newCommand("version")
	if b.cmd.Stdout == os.Stdout {
		t.Errorf("Set stdout to os.Stdout")
	}
	if b.cmd.Stderr == os.Stderr {
		t.Errorf("Set stderr to os.Stderr")
	}

	// If set to true it should write to the os version
	b.WriteToStderr(true)
	b.WriteToStdout(true)
	b.newCommand("version")
	if b.cmd.Stdout != os.Stdout {
		t.Errorf("Didn't set stdout to os.Stdout")
	}
	if b.cmd.Stderr != os.Stderr {
		t.Errorf("Didn't set stderr to os.Stderr")
	}

	// If set to false it should not write to the os version
	b.WriteToStderr(false)
	b.WriteToStdout(false)
	b.newCommand("version")
	if b.cmd.Stdout == os.Stdout {
		t.Errorf("Set stdout to os.Stdout")
	}
	if b.cmd.Stderr == os.Stderr {
		t.Errorf("Set stderr to os.Stderr")
	}
}

func TestQuery(t *testing.T) {
	b := New()
	got, err := b.processQuery(`//demo/path/to:target
//other/path/to:target
//third_party/path/to:target`)
	if err != nil {
		t.Errorf("Got error processing query: %s", err)
	}
	expected := []string{"//demo/path/to:target",
		"//other/path/to:target",
		"//third_party/path/to:target",
	}

	if !reflect.DeepEqual(got, expected) {
		t.Errorf("Got:\n%sExpected:\n%s", got, expected)
	}
}

// Test that cancel doesn't NPE if there is no command running.
func TestCancel(t *testing.T) {
	b := New()
	b.Cancel()
}
