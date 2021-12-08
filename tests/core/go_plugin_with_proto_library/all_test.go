package main_test

import (
	"go_plugin_with_proto_library/validate"
	"os"
	"plugin"
	"testing"
)

const RuleName = "test"

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
		return
	}

	symProto, err := p.Lookup("SomeProto")
	if err != nil {
		t.Error(err)
		return
	}

	proto := symProto.(*validate.MessageRules)
	if *proto.Name != RuleName {
		t.Errorf("expected %#v, got %#v", RuleName, proto.Name)
	}
}
