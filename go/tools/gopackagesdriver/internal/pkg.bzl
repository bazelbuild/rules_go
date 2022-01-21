def pkg_json_name(data):
    """Returns the pkg_json name for a given label.

    We are chosing to keep pkg.json files in a single directory and to replace
    the path separator with `Z` and hope that it is very unlikely to have these
    many Z's in the label itself.

    Args:
        data (GoArchiveData): the data for a particular go library.
    """
    root = data.label.workspace_root.replace("/", "Z")
    package = data.label.package.replace("/", "Z")

    return "{}Z{}Z{}Z{}.pkg.json".format(root, package, data.label.name, data.name)
