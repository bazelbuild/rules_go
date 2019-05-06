load("@io_bazel_rules_go//go/private:common.bzl", "has_shared_lib_extension")
load("@io_bazel_rules_go//go/private:skylib/lib/unittest.bzl", "asserts", "unittest")

def _versioned_shared_libraries_test(ctx):
    env = unittest.begin(ctx)

    # See //src/test/java/com/google/devtools/build/lib/rules/cpp:CppFileTypesTest.java
    # for the corresponding native C++ rules tests.
    asserts.true(env, has_shared_lib_extension("somelibrary.so"))
    asserts.true(env, has_shared_lib_extension("somelibrary.so.2"))
    asserts.true(env, has_shared_lib_extension("somelibrary.so.20"))
    asserts.true(env, has_shared_lib_extension("somelibrary.so.20.2"))
    asserts.true(env, has_shared_lib_extension("a/somelibrary.so.2"))
    asserts.false(env, has_shared_lib_extension("somelibrary.so.e"))
    asserts.false(env, has_shared_lib_extension("somelibrary.so.2e"))
    asserts.false(env, has_shared_lib_extension("somelibrary.so.e2"))
    asserts.false(env, has_shared_lib_extension("somelibrary.so.20.e2"))
    asserts.false(env, has_shared_lib_extension("somelibrary.a.2"))
    asserts.false(env, has_shared_lib_extension("somelibrary.a..2"))
    asserts.false(env, has_shared_lib_extension("somelibrary.so.2."))
    asserts.false(env, has_shared_lib_extension("somelibrary.so."))

    return unittest.end(env)

versioned_shared_libraries_test = unittest.make(_versioned_shared_libraries_test)

def common_test_suite():
    """Creates the test targets and test suite for common.bzl tests."""
    unittest.suite(
        "common_tests",
        versioned_shared_libraries_test,
    )
