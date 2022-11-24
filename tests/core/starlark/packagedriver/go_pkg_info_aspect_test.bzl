load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")
load("//go/tools/gopackagesdriver:aspect.bzl", "go_pkg_info_aspect")

def _package_driver_pkg_json_test_impl(ctx):
    env = analysistest.begin(ctx)

    target_under_test = analysistest.target_under_test(env)
    json_files = [f.basename for f in target_under_test[OutputGroupInfo].go_pkg_driver_json_file.to_list()]
    asserts.true(env, "go_default_test.pkg.json" in json_files, "{} does not contain go_default_test.pkg.json".format(json_files))

    return analysistest.end(env)

package_driver_pkg_json_test = analysistest.make(
    _package_driver_pkg_json_test_impl,
    extra_target_under_test_aspects = [go_pkg_info_aspect],
)

def _test_package_driver():
    package_driver_pkg_json_test(
        name = "package_driver_should_return_pkg_json_for_go_test",
        target_under_test = "//tests/core/starlark/packagedriver/fixtures/c:go_default_test",
    )

def package_driver_suite(name):
    _test_package_driver()

    native.test_suite(
        name = name,
        tests = [
            ":package_driver_should_return_pkg_json_for_go_test",
        ],
    )
