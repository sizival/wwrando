
; Triples the boomerang's flight speed from 60.0 to 180.0.
;
; The boomerang speed is stored at actor offset 0x254 and controls:
;   - Per-frame position displacement in procMove (speed * sin/cos of angles)
;   - Return distance threshold (returns to Link when distance < 2.0 * speed)
;   - Turning rate calculation (higher speed = wider turns)
;
; In procWait, when a throw begins, the speed constant 60.0 (@5144 at sdata2
; 0x803F99A4) is loaded and stored to offset 0x254. We hook this single store
; to write 180.0 instead. All subsequent reads from 0x254 in procMove will
; automatically use the tripled value.

.open "sys/main.dol"

; ============================================================================
; Custom constant in free space
; ============================================================================
.org @NextFreeSpace

.global boomerang_triple_speed
boomerang_triple_speed:
  .float 180.0 ; vanilla: 60.0

; ============================================================================
; Hook procWait speed initialization (0x800E1FE4)
;
; Original two instructions:
;   0x800E1FE4: lfs f0, "@5144"@sda21(r0)  ; f0 = 60.0
;   0x800E1FE8: stfs f0, 0x254(r30)         ; actor->speed = 60.0
;
; We replace both with a branch to our trampoline that loads 180.0 and stores
; it, then returns to the next instruction at 0x800E1FEC.
; ============================================================================
.org 0x800E1FE4
  b boomerang_speed_init_hook
  nop ; was: stfs f0, 0x254(r30) — done in trampoline

.org @NextFreeSpace
.global boomerang_speed_init_hook
boomerang_speed_init_hook:
  lis r12, boomerang_triple_speed@ha
  lfs f0, boomerang_triple_speed@l(r12)
  stfs f0, 0x254 (r30)
  b 0x800E1FEC ; return to addi r3, r30, 0xf88

.close

; ============================================================================
; Make boomerang one-shot Big Octo eyes
;
; The Big Octo eye actor (d_a_daiocta_eye) has 4 HP and a damage table in
; checkTgHit that checks attack type bits. AT_TYPE_BOOMERANG (0x40) is checked
; at PPC bit 25 and deals only 1 damage per hit (4 hits to kill).
;
; Patch the subi instruction at file offset 0x0A1C to subtract 4 instead of 1,
; making boomerang one-shot the eyes like bombs do.
;
; Original: subi r0, r3, 0x1  (38 03 FF FF)
; Patched:  subi r0, r3, 0x4  (38 03 FF FC)
; ============================================================================
.open "files/rels/d_a_daiocta_eye.rel"

.org 0x0A1C
  subi r0, r3, 0x4 ; vanilla: subi r0, r3, 0x1

.close
