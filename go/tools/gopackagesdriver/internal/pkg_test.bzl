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
            name="simple",
            label="//:foo",
            want="ZZfooZsimple.pkg.json",
        ),
        struct(
            name="longer",
            label="//foo/bar:baz",
            want="ZfooZbarZbazZlonger.pkg.json",
        ),
        struct(
            name="with_underscore",
            label="//foo:bar_baz",
            want="ZfooZbar_bazZwith_underscore.pkg.json",
        ),
        struct(
            name="name",
            label="//foo:baz",
            want="ZfooZbazZname.pkg.json",
        ),
        struct(
            name="name",
            label="//foo:go_default_library",
            want="ZfooZgo_default_libraryZname.pkg.json",
        ),
        struct(
            name="name",
            label="@foo//foo:baz",
            want="externalZfooZfooZbazZname.pkg.json",
        ),
        struct(
            name="name",
            label="@foo//:baz",
            want="externalZfooZZbazZname.pkg.json",
        ),
        struct(
            name="baz_test_",
            label="//:baz_test",
            want="ZZbaz_testZbaz_test_.pkg.json",
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

