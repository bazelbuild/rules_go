# Copyright 2017 The Bazel Authors. All rights reserved.
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

def json_marshal(value):
  """Encodes a dict, list, or scalar value as a JSON string.

  This is used for encoding arguments to action executables. It seems easier
  to encode / decode JSON than to encode lists and dict in command line
  arguments.

  This function has several limitations because Skylark does not allow
  recursion. In particular:

  * Dict keys are always interpreted as strings.
  * Dict values may be lists, or scalar values (no dicts).
  * List values may only be scalar values (no dicts or lists).
  """
  strs = []
  if type(value) == "dict":
    _marshal_dict(value, strs)
  elif type(value) == "list":
    _marshal_list(value, strs)
  else:
    _marshal_value(value, strs)
  return "".join(strs)

def _marshal_dict(d, strs):
  strs.append("{")
  sep = ""
  for k, v in d.items():
    strs.extend([sep, _quote(k), ":"])
    sep = ","
    if type(v) == "list":
      _marshal_list(v, strs)
    else:
      _marshal_value(v, strs)
  strs.append("}")

def _marshal_list(lst, strs):
  strs.append("[")
  sep = ""
  for e in lst:
    strs.append(sep)
    sep = ","
    _marshal_value(e, strs)
  strs.append("]")

def _marshal_value(v, strs):
  if type(v) == "string":
    strs.append(_quote(v))
  elif v in ("int", "float", "bool"):
    strs.append(str(v))
  elif v == None:
    strs.append("null")
  else:
    fail("could not marshal JSON value of type %s: %s" % (type(v), str(v)))

def _quote(s):
  # Limitation: Bazel does not support '\b', '\f' escape sequences.
  return ('"%s"' % s
      .replace('\\', '\\\\')
      .replace('"', '\\"')
      .replace('\n', '\\n')
      .replace('\r', '\\r')
      .replace('\t', '\\t'))
