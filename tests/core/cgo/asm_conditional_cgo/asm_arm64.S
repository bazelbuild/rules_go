/*
define this symbol both with and without underscore.
It seems like Mac OS X wants the underscore, but Linux does not.
*/
.global example_asm_func
.global _example_asm_func
.p2align 2 /* ld: warning: arm64 function not 4-byte aligned */
example_asm_func:
_example_asm_func:
    mov x0, #44
    ret

#if NOT_DEFINED
#error "should not fail"
#endif
