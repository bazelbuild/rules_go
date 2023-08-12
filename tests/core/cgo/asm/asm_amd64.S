/*
https://stackoverflow.com/questions/73435637/how-can-i-fix-usr-bin-ld-warning-trap-o-missing-note-gnu-stack-section-imp
*/
#if defined(__ELF__) && defined(__GNUC__)
.section .note.GNU-stack,"",@progbits
#endif

.global example_asm_func
.text
example_asm_func:
    mov $42, %rax
    ret

#if NOT_DEFINED
#error "should not fail"
#endif
