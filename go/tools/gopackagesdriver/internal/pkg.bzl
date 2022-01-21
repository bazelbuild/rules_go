def pkg_json_name(label):
    """Returns the pkg_json name for a given label.

    We are chosing to keep pkg.json files in a single directory and to replace
    the path separator with `Z` and hope that it is very unlikely to have these
    many Z's in the label itself.
    """
    root = label.workspace_root.replace("/", "Z")
    package = label.package.replace("/", "Z")
    name = label.name

    return "{}Z{}Z{}.pkg.json".format(root, package, name)
