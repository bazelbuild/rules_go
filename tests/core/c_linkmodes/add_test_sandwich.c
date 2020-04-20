#include <assert.h>
#include "tests/core/c_linkmodes/adder_sandwich_archive.h"

#ifndef CGO_EXPORT_H_EXISTS
#error cgo header did not include define
#endif

int main(int argc, char** argv) {
    assert(GoAdd(42, 42) == 84);
    return 0;
}
