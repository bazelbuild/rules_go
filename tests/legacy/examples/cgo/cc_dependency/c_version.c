#include <stdio.h>

#include "tests/legacy/examples/cgo/cc_dependency/c_version.h"

void PrintCVersion() {
#ifdef __STDC__
# ifdef __STDC_VERSION__
  printf("C version: %ld\n", __STDC_VERSION__);
# else
  printf("C version: C89\n");
# endif
#else
  printf("C version: maybe K&R\n");
#endif
}
