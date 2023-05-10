load(
    "@bazel_skylib//lib:shell.bzl",
    "shell",
)

def quote_opts(opts):
    return " ".join([shell.quote(opt) if " " in opt else opt for opt in opts])
