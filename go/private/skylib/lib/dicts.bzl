# This function isn't yet in a released skylib.

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
