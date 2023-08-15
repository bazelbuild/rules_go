/*
https://stackoverflow.com/questions/73435637/how-can-i-fix-usr-bin-ld-warning-trap-o-missing-note-gnu-stack-section-imp
*/
#if defined(__ELF__) && defined(__GNUC__)
.section .note.GNU-stack,"",@progbits
#endif

/*
define this symbol both with and without underscore.
It seems like Mac OS X wants the underscore, but Linux does not.
*/
.global example_asm_func
.global _example_asm_func
.text
example_asm_func:
_example_asm_func:
    mov $42, %rax
    ret

#if NOT_DEFINED
#error "should not fail"
#endif
