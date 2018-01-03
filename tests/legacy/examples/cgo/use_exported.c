#include <stdio.h>

#include "_cgo_export.h"

void PrintGoVersion() {
	GoString version = goVersion();
	printf("Go version: %.*s\n", (int)version.n, version.p);
}
