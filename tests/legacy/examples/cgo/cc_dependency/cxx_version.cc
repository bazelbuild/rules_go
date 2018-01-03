#include <dlfcn.h>
#include <iostream>

#include "tests/legacy/examples/cgo/cc_dependency/version.h"

// TODO(yugui) Support Darwin too once Bazel allows it.
//
// Bazel passes two or more -Wl,-rpath to $(CC) when it links a binary with
// shared libraries prebuilt outside of Bazel (i.e. when "srcs" attribute of
// the dependency cc_library contains ".so" files).
// Unfortunately tools/cpp/osx_cc_wrapper.sh, which is $(CC) on Darwin, expects
// only one -Wl,-rpath. So the binary fails to resolve the shared libraries
// at runtime.
#ifndef __APPLE_CC__
# include "tests/legacy/examples/cgo/cc_dependency/c_version.h"
#endif

extern "C" void PrintCXXVersion() {
#ifndef __APPLE_CC__
    PrintCVersion();
#endif
    void* ptr = dlsym(RTLD_DEFAULT, "PrintCXXVersion");
    if (ptr) {
        std::cout
            << "function ptr: " << std::hex << ptr << std::dec << std::endl;
    } else {
        std::cout << dlerror() << std::endl;
    }
    std::cout << "C++ version: " << __cplusplus << std::endl;
}
