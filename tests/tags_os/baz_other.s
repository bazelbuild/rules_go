// +build !linux,!darwin

TEXT ·baz(SB),$0-0
  MOVQ $56,RET(FP)
  RET
