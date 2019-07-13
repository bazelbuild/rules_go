#include <dlfcn.h>
#include <stdio.h>

#ifndef SO
#error No SO path defined
#endif

int main() {
  void* handle = dlopen(SO, RTLD_NOW);
  if (!handle) {
    printf("dlopen: %s\n", dlerror());
    return 1;
  }

  typedef void (*gofn_t)();
  gofn_t gofn = (gofn_t)dlsym(handle, "GoFn");
  const char* dlsym_error = dlerror();
  if (dlsym_error) {
    printf("dlsym: %s\n", dlerror());
    dlclose(handle);
    return 1;
  }

  gofn();

  if (dlclose(handle)) {
    printf("dlclose: %s\n", dlerror());
  }
  return 0;
}
