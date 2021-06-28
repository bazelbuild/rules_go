#include <add.h>
#include <generated_cppopts.h>
#include <generated_copts.h>

#if !defined(RULES_GO_C) || !defined(RULES_GO_CPP) || defined(RULES_GO_CXX)
#error This is a C file, only RULES_GO_C and RULES_GO_CPP should be defined.
#endif

#if !defined(GENERATED_COPTS) || !defined(GENERATED_CPPOPTS) || defined(GENERATED_CXXOPTS)
#error Generated headers should be correctly included
#endif

int add_c(int a, int b) {
    int $ = 0;
    int sum = a + b;
    sum += DOLLAR_SIGN_C;
    sum += DOLLAR_SIGN_CPP;
    return sum;
}
