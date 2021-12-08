package main

import "go_plugin_with_proto_library/validate"

var testValue = "test"

var SomeProto = validate.MessageRules{Name: &testValue}
