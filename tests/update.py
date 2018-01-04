#!/usr/bin/env python
# Copyright 2018 The Bazel Authors. All rights reserved.
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

"""
This script should be run without any arguments to update the tests
documentation cross linking.

It updates sections bounded by
.. Child list start
.. Child list end

With links to all the child documentation, picking the text for each item
from the firts non blank line of the README.rst for that folder.
"""

import os

README = "README.rst"
START_MARKER = ".. Child list start\n"
END_MARKER = ".. Child list end\n"

def main():
  for dirname, subdirs, files in os.walk("."):
    if README not in files:
      continue
    readme = os.path.join(dirname, README)
    out = []
    lines = []
    with open(readme) as f:
      lines = f.readlines()
    try:
      start = lines.index(START_MARKER)
      end = lines.index(END_MARKER)
    except ValueError:
      print('{}: No child markers'.format(readme))
      continue
    if end < start:
      print('{}: Invalid child markers'.format(readme))
      continue
    print('{}: updating from {} to {}'.format(readme, start, end))
    out = lines[:start+1]
    out.append("\n")
    for sub in subdirs:
      child = os.path.join(dirname, sub, README)
      try:
        with open(child) as f:
          for line in f.readlines():
            childname = line.strip()
            if childname:
              break
        if childname:
          out.append("* `{} <{}/{}>`_\n".format(childname, sub, README))
      except:
        continue
    out.append("\n")
    out.extend(lines[end:])
    if out:
      with open(readme, "w") as f:
        f.writelines(out)


if __name__ == "__main__":
    main()