// Example assembly copied from https://github.com/rpccloud/goid

#include "go_asm.h"
#include "textflag.h"

#ifdef GOARCH_386
#define	get_tls(r)	MOVL TLS, r
#define	g(r)	0(r)(TLS*1)
#endif

TEXT ·getg(SB), NOSPLIT, $0-4
    get_tls(CX)
    MOVL    g(CX), AX
    MOVL    AX, ret+0(FP)
    RET
