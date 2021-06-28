#include "add.h"
#include <generated_cppopts.h>
#include <generated_cxxopts.h>

#if !defined(RULES_GO_CPP) || !defined(RULES_GO_CXX) || defined(RULES_GO_C)
#error This is a C++ file, only RULES_GO_CXX and RULES_GO_CPP should be defined.
#endif

#if !defined(GENERATED_CPPOPTS) || !defined(GENERATED_CXXOPTS) || defined(GENERATED_COPTS)
#error Generated headers should be correctly included
#endif

int add_cpp(int a, int b) {
    int $ = 0;
    int sum = a + b;
    sum += DOLLAR_SIGN_CXX;
    sum += DOLLAR_SIGN_CPP;
    return sum;
}
