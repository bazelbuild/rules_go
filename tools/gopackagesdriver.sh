#!/usr/bin/env bash
export GOPACKAGESDRIVER_RULES_GO_REPOSITORY_NAME=
exec bazel run --tool_tag=gopackagesdriver -- //go/tools/gopackagesdriver "${@}"
