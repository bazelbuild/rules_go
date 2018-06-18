package main_test

import (
	"os"
	"plugin"
	"testing"
)

const HelloWorld = "Hello, world!"

func TestPluginCreated(t *testing.T) {
	_, err := os.Stat("plugin.so")
	if err != nil {
		t.Error(err)
	}
}

func TestPluginWorks(t *testing.T) {
	p, err := plugin.Open("plugin.so")
	if err != nil {
		t.Error(err)
	}

	f, err := p.Lookup("Hi")
	if err != nil {
		t.Error(err)
	}

	helloWorld := f.(func() string)()
	if helloWorld != HelloWorld {
		t.Errorf("expected %#v, got %#v", HelloWorld, helloWorld)
	}
}
