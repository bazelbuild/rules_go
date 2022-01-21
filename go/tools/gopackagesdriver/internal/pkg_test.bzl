"""Unit tests for pkg.json creation related functions"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(":pkg.bzl", "pkg_json_name")

def _pkg_json_name(ctx):
    env = unittest.begin(ctx)
    cases = {
        "ZZfoo.pkg.json": "//:foo",
        "ZfooZbarZbaz.pkg.json": "//foo/bar:baz",
        "ZfooZbar_baz.pkg.json": "//foo:bar_baz",
        "ZfooZbaz.pkg.json": "//foo:baz",
        "ZfooZgo_default_library.pkg.json": "//foo:go_default_library",
        "externalZfooZfooZbaz.pkg.json": "@foo//foo:baz",
        "externalZfooZZbaz.pkg.json": "@foo//:baz",
    }

    for (want, input) in cases.items():
        asserts.equals(
            env,
            want,
            pkg_json_name(Label(input)),
        )
    return unittest.end(env)

pkg_json_name_test = unittest.make(_pkg_json_name)

def actions_test_suite():
    unittest.suite(
        "actions",
        pkg_json_name_test,
    )

