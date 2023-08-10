.global _example_asm_func
.p2align 2 /* ld: warning: arm64 function not 4-byte aligned */
_example_asm_func:
    mov x0, #44
    ret

#if NOT_DEFINED
#error "should not fail
#endif
