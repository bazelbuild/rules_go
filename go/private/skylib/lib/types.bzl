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
"""Skylib module containing functions checking types."""

# create instance singletons to avoid unnecessary allocations
_a_bool = True
_a_dict = {}
_a_list = []
_a_string = ""
_a_tuple = ()
_an_int = 1

def _a_function():
    pass

def _is_list(v):
    """Returns True if v is an instance of a list.

    Args:
      v: The value whose type should be checked.

    Returns:
      True if v is an instance of a list, False otherwise.
    """
    return type(v) == type(_a_list)

def _is_string(v):
    """Returns True if v is an instance of a string.

    Args:
      v: The value whose type should be checked.

    Returns:
      True if v is an instance of a string, False otherwise.
    """
    return type(v) == type(_a_string)

def _is_bool(v):
    """Returns True if v is an instance of a bool.

    Args:
      v: The value whose type should be checked.

    Returns:
      True if v is an instance of a bool, False otherwise.
    """
    return type(v) == type(_a_bool)

def _is_none(v):
    """Returns True if v has the type of None.

    Args:
      v: The value whose type should be checked.

    Returns:
      True if v is None, False otherwise.
    """
    return type(v) == type(None)

def _is_int(v):
    """Returns True if v is an instance of a signed integer.

    Args:
      v: The value whose type should be checked.

    Returns:
      True if v is an instance of a signed integer, False otherwise.
    """
    return type(v) == type(_an_int)

def _is_tuple(v):
    """Returns True if v is an instance of a tuple.

    Args:
      v: The value whose type should be checked.

    Returns:
      True if v is an instance of a tuple, False otherwise.
    """
    return type(v) == type(_a_tuple)

def _is_dict(v):
    """Returns True if v is an instance of a dict.

    Args:
      v: The value whose type should be checked.

    Returns:
      True if v is an instance of a dict, False otherwise.
    """
    return type(v) == type(_a_dict)

def _is_function(v):
    """Returns True if v is an instance of a function.

    Args:
      v: The value whose type should be checked.

    Returns:
      True if v is an instance of a function, False otherwise.
    """
    return type(v) == type(_a_function)

types = struct(
    is_list = _is_list,
    is_string = _is_string,
    is_bool = _is_bool,
    is_none = _is_none,
    is_int = _is_int,
    is_tuple = _is_tuple,
    is_dict = _is_dict,
    is_function = _is_function,
)
