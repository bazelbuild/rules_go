// +build !linux,amd64

TEXT ·asm(SB),$0-0
  MOVQ $34,RET(FP)
  RET
