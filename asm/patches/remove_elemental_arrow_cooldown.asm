; Remove the cooldown after firing elemental arrows (fire/ice/light).
; The USE_ARROW_EFFECT flag prevents nocking another arrow until the
; environmental color change effect finishes. NOP the branch that skips
; arrow reload when this flag is set.
.open "sys/main.dol"
.org 0x8014A550 ; In checkNextActionBowReady, skip the USE_ARROW_EFFECT check
  nop
.close
