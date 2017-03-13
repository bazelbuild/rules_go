#include "foo_amd64.h"

TEXT ·foo(SB),$0-0
  MOVQ $FOOVAL,RET(FP)
  RET
