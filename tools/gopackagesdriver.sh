#!/usr/bin/env bash
exec bazel run --tool_tag=gopackagesdriver -- //go/tools/gopackagesdriver "${@}"
