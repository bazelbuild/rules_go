# This function isn't yet in a released skylib. It's taken from https://github.com/bazelbuild/bazel-skylib/blob/8334f938c1574ef6f1f7a38a03550a31df65274e/lib/dicts.bzl

def _omit(dictionary, keys):
    """Returns a new `dict` that has all the entries of `dictionary` with keys not in `keys`.
    Args:
      dictionary: A `dict`.
      keys: A sequence.
    Returns:
      A new `dict` that has all the entries of `dictionary` with keys not in `keys`.
    """
    keys_set = {k: None for k in keys}
    return {k: dictionary[k] for k in dictionary if k not in keys_set}

dicts = struct(
    omit = _omit,
)
