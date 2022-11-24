## Examples

### go_library
``` bzl
go_library(
    name = "foo",
    srcs = [
        "foo.go",
        "bar.go",
    ],
    deps = [
        "//tools",
        "@org_golang_x_utils//stuff",
    ],
    importpath = "github.com/example/project/foo",
    visibility = ["//visibility:public"],
)
```

### go_test

To write an internal test, reference the library being tested with the `embed`
instead of `deps`. This will compile the test sources into the same package as the library
sources.

#### Internal test example

This builds a test that can use the internal interface of the package being tested.

In the normal go toolchain this would be the kind of tests formed by adding writing
`<file>_test.go` files in the same package.

It references the library being tested with `embed`.


``` bzl
go_library(
    name = "lib",
    srcs = ["lib.go"],
)

go_test(
    name = "lib_test",
    srcs = ["lib_test.go"],
    embed = [":lib"],
)
```

#### External test example

This builds a test that can only use the public interface(s) of the packages being tested.

In the normal go toolchain this would be the kind of tests formed by adding an `<name>_test`
package.

It references the library(s) being tested with `deps`.

``` bzl
go_library(
    name = "lib",
    srcs = ["lib.go"],
)

go_test(
    name = "lib_xtest",
    srcs = ["lib_x_test.go"],
    deps = [":lib"],
)
```

