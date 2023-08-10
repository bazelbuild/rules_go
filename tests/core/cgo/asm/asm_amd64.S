/*
https://stackoverflow.com/questions/73435637/how-can-i-fix-usr-bin-ld-warning-trap-o-missing-note-gnu-stack-section-imp
*/
.section .note.GNU-stack,"",@progbits

.global example_asm_func
.text
example_asm_func:
    mov $42, %rax
    ret

#if NOT_DEFINED
#error "should not fail
#endif
