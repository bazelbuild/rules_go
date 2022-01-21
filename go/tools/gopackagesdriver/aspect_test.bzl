"""Unit tests for aspect functions"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(":aspect.bzl", "pkg_json_name")

def _pkg_json_name(ctx):
    env = unittest.begin(ctx)
    tests = {
        "_foo.pkg.json": "//:foo",
        "foo_go_default_library.pkg.json": "//foo:go_default_library",
        "foo_bar_baz.pkg.json": "//foo/bar:baz",
        "foo_baz.pkg.json": "//foo:baz",
    }

    for (want, input) in tests.items():
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

