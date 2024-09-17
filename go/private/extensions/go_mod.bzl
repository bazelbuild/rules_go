# Copyright 2023 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

visibility(["//go/private"])

def sdk_from_go_mod(module_ctx, go_mod_label):
    """Loads the Go SDK information from go.mod.

    Args:
        module_ctx: a https://bazel.build/rules/lib/module_ctx object passed
            from the MODULE.bazel call.
        go_mod_label: a Label for a `go.mod` file.

    Returns:
        a struct with the following fields:
            go: a string containing the effective go directive value (never None)
            toolchain: a string containing the raw toolchain directive value (can be None)
    """
    if go_mod_label.name != "go.mod":
        fail("go_deps.from_file requires a 'go.mod' file, not '{}'".format(go_mod_label.name))

    go_mod_path = module_ctx.path(go_mod_label)
    go_mod_content = module_ctx.read(go_mod_path)
    return _parse_go_mod(go_mod_content, go_mod_path)

def _parse_go_mod(content, path):
    # See https://go.dev/ref/mod#go-mod-file.

    # Valid directive values understood by this parser never contain tabs or
    # carriage returns, so we can simplify the parsing below by canonicalizing
    # whitespace upfront.
    content = content.replace("\t", " ").replace("\r", " ")

    state = {
        "go": None,
        "toolchain": None,
    }

    # Since we only care about simple directives, we parse the file in a lax way
    # and just skip over anything that looks like a block.
    in_block = None
    for line_no, line in enumerate(content.splitlines(), 1):
        tokens, comment = _tokenize_line(line, path, line_no)
        if not tokens:
            continue
        tok = tokens[0]
        if not in_block:
            if tok in ("go", "toolchain"):
                if len(tokens) == 1:
                    fail("{}:{}: expected another token after '{}'".format(path, line_no, tok))
                if state[tok] != None:
                    fail("{}:{}: unexpected second '{}' directive".format(path, line_no, tok))
                if len(tokens) > 2:
                    fail("{}:{}: unexpected token '{}' after '{}'".format(path, line_no, tokens[2], tokens[1]))
                state[tok] = tokens[1]
                continue
            if len(tokens) >= 2 and tokens[1] == "(":
                in_block = True
                if len(tokens) > 2:
                    fail("{}:{}: unexpected token '{}' after '('".format(path, line_no, tokens[2]))
        elif tok == ")":
            in_block = False
            if len(tokens) > 1:
                fail("{}:{}: unexpected token '{}' after ')'".format(path, line_no, tokens[1]))

    return struct(
        # "As of the Go 1.17 release, if the go directive is missing, go 1.16 is assumed."
        go = state["go"] or "1.16",
        toolchain = state["toolchain"],
    )

def _tokenize_line(line, path, line_no):
    tokens = []
    r = line
    for _ in range(len(line)):
        r = r.strip()
        if not r:
            break

        if r[0] == "`":
            end = r.find("`", 1)
            if end == -1:
                fail("{}:{}: unterminated raw string".format(path, line_no))

            tokens.append(r[1:end])
            r = r[end + 1:]

        elif r[0] == "\"":
            value = ""
            escaped = False
            found_end = False
            for pos in range(1, len(r)):
                c = r[pos]

                if escaped:
                    value += c
                    escaped = False
                    continue

                if c == "\\":
                    escaped = True
                    continue

                if c == "\"":
                    found_end = True
                    break

                value += c

            if not found_end:
                fail("{}:{}: unterminated interpreted string".format(path, line_no))

            tokens.append(value)
            r = r[pos + 1:]

        elif r.startswith("//"):
            # A comment always ends the current line
            return tokens, r[len("//"):].strip()

        else:
            token, _, r = r.partition(" ")
            tokens.append(token)

    return tokens, None
