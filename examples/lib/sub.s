#include "textflag.h"

TEXT ·sub(SB),NOSPLIT,$0
	MOVQ x+0(FP), BX
	MOVQ y+8(FP), BP
	SUBQ BP, BX
	MOVQ BX, ret+16(FP)
	RET
