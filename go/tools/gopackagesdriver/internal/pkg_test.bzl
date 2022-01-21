"""Unit tests for pkg.json creation related functions"""

load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load(
    "//go/private:providers.bzl",
    "GoArchiveData",
)
load(":pkg.bzl", "pkg_json_name")

def _pkg_json_name(ctx):
    env = unittest.begin(ctx)
    testcases = [
        struct(
            want="ZZfooZname.pkg.json",
            label="//:foo",
            name="name",
        ),
        struct(
            want="ZfooZbarZbazZname.pkg.json",
            label="//foo/bar:baz",
            name="name",
        ),
        struct(
            want="ZfooZbar_bazZname.pkg.json",
            label="//foo:bar_baz",
            name="name",
        ),
        struct(
            want="ZfooZbazZname.pkg.json",
            label="//foo:baz",
            name="name",
        ),
        struct(
            want="ZfooZgo_default_libraryZname.pkg.json",
            label="//foo:go_default_library",
            name="name",
        ),
        struct(
            want="externalZfooZfooZbazZname.pkg.json",
            label="@foo//foo:baz",
            name="name",
        ),
        struct(
            want="externalZfooZZbazZname.pkg.json",
            label="@foo//:baz",
            name="name",
        ),
        struct(
            want="ZZbaz_testZbaz_test_.pkg.json",
            label="//:baz_test",
            name="baz_test_",
        ),
    ]

    for tt in testcases:
        asserts.equals(
            env,
            tt.want,
            pkg_json_name(GoArchiveData(
                name = tt.name,
                label = Label(tt.label)
            )),
        )
    return unittest.end(env)

pkg_json_name_test = unittest.make(_pkg_json_name)

def actions_test_suite():
    unittest.suite(
        "actions",
        pkg_json_name_test,
    )

