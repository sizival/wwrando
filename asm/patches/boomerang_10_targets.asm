
; Increases the boomerang's maximum lock-on targets from 5 to 10.
; Uses static buffers in main.dol free space since only one boomerang actor exists at a time.
;
; Addresses verified against framework.map and main.asm disassembly.
.open "sys/main.dol"

; ============================================================================
; Static buffers in free space
; ============================================================================
.org @NextFreeSpace

.global boomerang_lock_ids
boomerang_lock_ids:
  .int 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF
  .int 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF

.global boomerang_lock_ptrs
boomerang_lock_ptrs:
  .int 0, 0, 0, 0, 0
  .int 0, 0, 0, 0, 0

.global boomerang_lock_flags
boomerang_lock_flags:
  .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .align 2

.global boomerang_lock_count
boomerang_lock_count:
  .byte 0

.global boomerang_lock_state
boomerang_lock_state:
  .byte 0
  .align 2

.global boomerang_sight_matrices
boomerang_sight_matrices:
  .space 480

.global boomerang_sight_counters
boomerang_sight_counters:
  .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .align 2

.global boomerang_sight_alphas
boomerang_sight_alphas:
  .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .align 2

.global boomerang_se_flg_table
boomerang_se_flg_table:
  .int 0x000000C8, 0x000000C9, 0x000000CA, 0x000000CB, 0x000000CC
  .int 0x000000CC, 0x000000CC, 0x000000CC, 0x000000CC, 0x000000CC

; ============================================================================
; setLockActor REWRITE (0x800E1B20, size 0x100)
; Original signature: r3=this, r4=fopAc_ac_c* actor, r5=int play_sound
; The actor ID is extracted from r4->offset4 (or 0xFFFFFFFF if r4 is NULL).
; ============================================================================
.org 0x800E1B20
  b setLockActor_custom
.org @NextFreeSpace
.global setLockActor_custom
setLockActor_custom:
  stwu sp, -0x30 (sp)
  mflr r0
  stw r0, 0x34 (sp)
  stw r31, 0x2C (sp)
  stw r30, 0x28 (sp)
  stw r29, 0x24 (sp)
  stw r28, 0x20 (sp)
  mr r31, r3 ; this (daBoomerang_c*)
  mr r30, r4 ; actor pointer (fopAc_ac_c*)
  mr r29, r5 ; play_sound flag

  ; Extract actor ID from pointer (or -1 if NULL)
  cmplwi r30, 0
  beq setLockActor_null_actor
  lwz r28, 4 (r30) ; r28 = actor->id (offset 4 in fopAc_ac_c)
  b setLockActor_have_id
setLockActor_null_actor:
  li r28, -1 ; 0xFFFFFFFF
setLockActor_have_id:

  ; Load current lock count from static buffer
  lis r3, boomerang_lock_count@ha
  addi r3, r3, boomerang_lock_count@l
  lbz r7, 0 (r3)

  ; Check if already at max (10)
  cmplwi r7, 10
  bge setLockActor_fail

  ; Check for duplicate: loop through existing entries
  lis r8, boomerang_lock_ids@ha
  addi r8, r8, boomerang_lock_ids@l
  li r9, 0
setLockActor_dup_loop:
  cmpw r9, r7
  bge setLockActor_no_dup
  slwi r10, r9, 2
  lwzx r11, r8, r10
  cmplw r11, r28
  beq setLockActor_fail
  addi r9, r9, 1
  b setLockActor_dup_loop

setLockActor_no_dup:
  ; Store new target ID in static buffer
  slwi r10, r7, 2
  stwx r28, r8, r10

  ; Store new target pointer in static buffer
  lis r8, boomerang_lock_ptrs@ha
  addi r8, r8, boomerang_lock_ptrs@l
  stwx r30, r8, r10

  ; Store flag=0 in static buffer
  lis r8, boomerang_lock_flags@ha
  addi r8, r8, boomerang_lock_flags@l
  li r9, 0
  stbx r9, r8, r7

  ; Also write to actor struct for backward compat (first 5 only)
  cmplwi r7, 5
  bge setLockActor_skip_struct_write
  slwi r10, r7, 2
  add r9, r31, r10
  stw r28, 0xF04 (r9)
  stw r30, 0xF18 (r9)
  add r9, r31, r7
  li r10, 0
  stb r10, 0x388 (r9)
setLockActor_skip_struct_write:

  ; Play sound if requested (before incrementing count, to use current count as index)
  cmplwi r29, 0
  beq setLockActor_skip_sound

  ; Load sound ID from our extended table (indexed by current count = the new entry)
  lis r8, boomerang_se_flg_table@ha
  addi r8, r8, boomerang_se_flg_table@l
  slwi r10, r7, 2
  lwzx r4, r8, r10

  ; Call seStart
  lwz r3, -0x69D0 (r13)
  li r5, 0
  li r6, 0
  li r7, 0
  lfs f1, -0x63B0 (r2)
  fmr f2, f1
  lfs f3, -0x636C (r2)
  fmr f4, f3
  li r8, 0
  bl seStart__11JAIZelBasicFUlP3VecUlScffffUc

  ; Reload count since r7 was clobbered by the sound call
  lis r3, boomerang_lock_count@ha
  addi r3, r3, boomerang_lock_count@l
  lbz r7, 0 (r3)

setLockActor_skip_sound:
  ; Increment count
  addi r7, r7, 1
  lis r3, boomerang_lock_count@ha
  addi r3, r3, boomerang_lock_count@l
  stb r7, 0 (r3)

  ; Update struct count (capped at 5)
  cmplwi r7, 5
  ble setLockActor_store_struct_count
  li r9, 5
  stb r9, 0xF31 (r31)
  b setLockActor_success
setLockActor_store_struct_count:
  stb r7, 0xF31 (r31)

setLockActor_success:
  li r3, 1
  b setLockActor_epilog

setLockActor_fail:
  li r3, 0

setLockActor_epilog:
  lwz r28, 0x20 (sp)
  lwz r29, 0x24 (sp)
  lwz r30, 0x28 (sp)
  lwz r31, 0x2C (sp)
  lwz r0, 0x34 (sp)
  mtlr r0
  addi sp, sp, 0x30
  blr

; ============================================================================
; resetLockActor REWRITE (0x800E1C20, size 0x38)
; r3 = daBoomerang_c* this
; ============================================================================
.org 0x800E1C20
  b resetLockActor_custom
.org @NextFreeSpace
.global resetLockActor_custom
resetLockActor_custom:
  ; Clear static lock IDs (10 entries)
  lis r4, boomerang_lock_ids@ha
  addi r4, r4, boomerang_lock_ids@l
  li r0, 10
  mtctr r0
  li r5, -1
resetLock_clear_ids:
  stw r5, 0 (r4)
  addi r4, r4, 4
  bdnz resetLock_clear_ids

  ; Clear static lock pointers (10 entries)
  lis r4, boomerang_lock_ptrs@ha
  addi r4, r4, boomerang_lock_ptrs@l
  li r0, 10
  mtctr r0
  li r5, 0
resetLock_clear_ptrs:
  stw r5, 0 (r4)
  addi r4, r4, 4
  bdnz resetLock_clear_ptrs

  ; Clear static count and state
  lis r4, boomerang_lock_count@ha
  addi r4, r4, boomerang_lock_count@l
  li r5, 0
  stb r5, 0 (r4)
  lis r4, boomerang_lock_state@ha
  addi r4, r4, boomerang_lock_state@l
  stb r5, 0 (r4)

  ; Also clear struct arrays (5 entries for compat)
  li r0, 5
  mtctr r0
  addi r4, r3, 0xF04
  li r5, -1
resetLock_clear_struct_ids:
  stw r5, 0 (r4)
  addi r4, r4, 4
  bdnz resetLock_clear_struct_ids

  li r0, 5
  mtctr r0
  addi r4, r3, 0xF18
  li r5, 0
resetLock_clear_struct_ptrs:
  stw r5, 0 (r4)
  addi r4, r4, 4
  bdnz resetLock_clear_struct_ptrs

  li r5, 0
  stb r5, 0xF31 (r3)
  stb r5, 0xF32 (r3)
  blr

; ============================================================================
; sightPacket::draw patches (0x800E13A4, size 0x14C)
; All addresses verified against main.asm disassembly.
; ============================================================================

; Loop limit: 5 -> 10
; File 0xDE40C: cmpwi r28, 5
.org 0x800E14CC
  cmpwi r28, 0xA

; Alpha access trampoline
; File 0xDE3B4: addi r0, r28, 0xF9
; File 0xDE3B8: lbzx r0, r31, r0
.org 0x800E1474
  b draw_alpha_trampoline
.org @NextFreeSpace
.global draw_alpha_trampoline
draw_alpha_trampoline:
  lis r12, boomerang_sight_alphas@ha
  addi r12, r12, boomerang_sight_alphas@l
  lbzx r0, r12, r28
  b 0x800E147C

; Matrix access trampoline
; File 0xDE3EC: addi r3, r30, 4
; File 0xDE3F0: add r3, r31, r3
.org 0x800E14AC
  b draw_matrix_trampoline
.org @NextFreeSpace
.global draw_matrix_trampoline
draw_matrix_trampoline:
  mulli r3, r28, 0x30
  lis r12, boomerang_sight_matrices@ha
  addi r12, r12, boomerang_sight_matrices@l
  add r3, r12, r3
  b 0x800E14B4

; ============================================================================
; sightPacket::play patch (0x800E1718, size 0x3C)
; File 0xDE658: addi r5, r3, 0xF4
; ============================================================================
.org 0x800E1718
  b play_counters_trampoline
.org @NextFreeSpace
.global play_counters_trampoline
play_counters_trampoline:
  lis r5, boomerang_sight_counters@ha
  addi r5, r5, boomerang_sight_counters@l
  li r4, 10
  b 0x800E171C

; ============================================================================
; sightPacket::setSight patches (0x800E14F0, size 0x228)
; ============================================================================

; Counter read trampoline
; File 0xDE474: add r3, r30, r31
; File 0xDE478: lbz r3, 0xF4(r3)
.org 0x800E1534
  b setSight_counter_trampoline
.org @NextFreeSpace
.global setSight_counter_trampoline
setSight_counter_trampoline:
  lis r3, boomerang_sight_counters@ha
  addi r3, r3, boomerang_sight_counters@l
  lbzx r3, r3, r31
  b 0x800E153C

; Alpha store trampoline (CORRECTED ADDRESS)
; File 0xDE500: add r3, r30, r31
; File 0xDE504: stb r0, 0xF9(r3)
.org 0x800E15C0
  b setSight_alpha_store_trampoline
  nop
.org @NextFreeSpace
.global setSight_alpha_store_trampoline
setSight_alpha_store_trampoline:
  lis r3, boomerang_sight_alphas@ha
  addi r3, r3, boomerang_sight_alphas@l
  stbx r0, r3, r31
  b 0x800E15C8

; Matrix destination trampoline (CORRECTED ADDRESS)
; File 0xDE5E4: mulli r4, r31, 48
; File 0xDE5E8: addi r4, r4, 4
; File 0xDE5EC: add r4, r30, r4
.org 0x800E16A4
  b setSight_matrix_dest_trampoline
  nop
  nop
.org @NextFreeSpace
.global setSight_matrix_dest_trampoline
setSight_matrix_dest_trampoline:
  mulli r4, r31, 0x30
  lis r12, boomerang_sight_matrices@ha
  addi r12, r12, boomerang_sight_matrices@l
  add r4, r12, r4
  b 0x800E16B0

; ============================================================================
; rockLineCallback REWRITE (0x800E1A14, size 0x98)
; Original: loops 5 targets, checks collision, uses struct arrays.
; Rewrite: loops 10 targets, uses static buffers.
; r3 = this, r4 = colliding actor pointer
; ============================================================================
.org 0x800E1A14
  b rockLineCallback_custom
.org @NextFreeSpace
.global rockLineCallback_custom
rockLineCallback_custom:
  stwu sp, -0x10 (sp)
  mflr r0
  stw r0, 0x14 (sp)

  ; Check state at offset 0xB0
  lwz r0, 0xB0 (r3)
  cmplwi r0, 0
  bne rockLine_check_collision

  ; State 0: no boomerang in flight, try to lock on
  cmplwi r4, 0
  beq rockLine_epilog
  ; r3=this, r4=actor ptr (already correct), r5=play_sound
  li r5, 1
  bl setLockActor_custom
  b rockLine_epilog

rockLine_check_collision:
  ; Loop through all 10 targets checking for collision
  li r10, 0       ; r10 = loop index
  li r9, -1       ; r9 = 0xFFFFFFFF (for invalidating)
  li r8, 0        ; r8 = 0 (for clearing ptr)
  li r7, 1        ; r7 = 1 (for setting flag)

  lis r6, boomerang_lock_ptrs@ha
  addi r6, r6, boomerang_lock_ptrs@l
  lis r11, boomerang_lock_ids@ha
  addi r11, r11, boomerang_lock_ids@l
  lis r12, boomerang_lock_count@ha
  addi r12, r12, boomerang_lock_count@l
  lbz r0, 0 (r12) ; r0 = total lock count
  mtctr r0
  cmplwi r0, 0
  beq rockLine_epilog

rockLine_loop:
  slwi r5, r10, 2
  lwzx r0, r6, r5        ; load target ptr from static buffer
  cmplw r0, r4            ; compare with colliding actor
  bne rockLine_skip

  ; Match! Clear this target in static buffers
  stwx r9, r11, r5       ; invalidate ID in static buffer
  stwx r8, r6, r5        ; clear ptr in static buffer

  ; Also clear in struct (if index < 5)
  cmplwi r10, 5
  bge rockLine_skip_struct_clear
  add r12, r3, r5
  stw r9, 0xF04 (r12)
  stw r8, 0xF18 (r12)
rockLine_skip_struct_clear:

  ; Check if this is the current target
  lis r12, boomerang_lock_state@ha
  addi r12, r12, boomerang_lock_state@l
  lbz r5, 0 (r12)        ; current target index
  cmpw r10, r5
  bne rockLine_skip

  ; This IS the current target - advance and set flag
  stb r7, 0xF2E (r3)     ; set hit flag
  addi r5, r5, 1
  stb r5, 0 (r12)        ; increment state in static buffer
  stb r5, 0xF32 (r3)     ; also update struct

rockLine_skip:
  addi r10, r10, 1
  bdnz rockLine_loop

rockLine_epilog:
  lwz r0, 0x14 (sp)
  mtlr r0
  addi sp, sp, 0x10
  blr

; ============================================================================
; "Update sights" function patches (0x800E1754)
; This function loops from F32 to F31, calling setSight for each target.
; It accesses F31, F32, and F18[idx].
; ============================================================================

; F31 read (lock count check): File 0xDE6D8: lbz r0, 0xF31(r30)
.org 0x800E1798
  b updateSights_count_check_trampoline
.org @NextFreeSpace
.global updateSights_count_check_trampoline
updateSights_count_check_trampoline:
  lis r12, boomerang_lock_count@ha
  addi r12, r12, boomerang_lock_count@l
  lbz r0, 0 (r12)
  b 0x800E179C

; F32 read (start index): File 0xDE6EC: lbz r28, 0xF32(r30)
.org 0x800E17AC
  b updateSights_state_read_trampoline
.org @NextFreeSpace
.global updateSights_state_read_trampoline
updateSights_state_read_trampoline:
  lis r28, boomerang_lock_state@ha
  addi r28, r28, boomerang_lock_state@l
  lbz r28, 0 (r28)
  b 0x800E17B0

; F18 target ptr read: File 0xDE6F8-0xDE6FC:
; addi r0, r29, 0xF18 ; r29 = byte offset (index * 4)
; lwzx r4, r30, r0    ; r4 = this[byte_offset + 0xF18]
.org 0x800E17B8
  b updateSights_ptr_trampoline
  nop
.org @NextFreeSpace
.global updateSights_ptr_trampoline
updateSights_ptr_trampoline:
  lis r12, boomerang_lock_ptrs@ha
  addi r12, r12, boomerang_lock_ptrs@l
  lwzx r4, r12, r29 ; r4 = boomerang_lock_ptrs[byte_offset]
  b 0x800E17C0

; F31 read (loop condition): File 0xDE734: lbz r0, 0xF31(r30)
.org 0x800E17F4
  b updateSights_loop_cond_trampoline
.org @NextFreeSpace
.global updateSights_loop_cond_trampoline
updateSights_loop_cond_trampoline:
  lis r12, boomerang_lock_count@ha
  addi r12, r12, boomerang_lock_count@l
  lbz r0, 0 (r12)
  b 0x800E17F8

; ============================================================================
; setAimPos patches (0x800E1DA8, size ~0xC4)
; Loops from F32 scanning for non-NULL target ptrs in F18.
; ============================================================================

; F32 initial read: File 0xDED38: lbz r5, 0xF32(r31)
.org 0x800E1DF8
  b setAimPos_state_read_trampoline
.org @NextFreeSpace
.global setAimPos_state_read_trampoline
setAimPos_state_read_trampoline:
  lis r5, boomerang_lock_state@ha
  addi r5, r5, boomerang_lock_state@l
  lbz r5, 0 (r5)
  b 0x800E1DFC

; F18 target ptr access (check NULL): File 0xDED44-0xDED48:
; addi r0, r3, 0xF18 ; r3 = byte offset (idx * 4)
; lwzx r0, r31, r0   ; r0 = this[byte_offset + 0xF18]
.org 0x800E1E04
  b setAimPos_ptr_check_trampoline
  nop
.org @NextFreeSpace
.global setAimPos_ptr_check_trampoline
setAimPos_ptr_check_trampoline:
  lis r12, boomerang_lock_ptrs@ha
  addi r12, r12, boomerang_lock_ptrs@l
  lwzx r0, r12, r3 ; load ptr from static buffer using byte offset
  b 0x800E1E0C

; F18 target ptr access (load for position): File 0xDED54-0xDED58:
; add r3, r31, r3   ; r3 = this + byte_offset
; lwz r3, 0xF18(r3) ; r3 = target_ptr
; Since r0 already has the target pointer from our ptr_check trampoline above,
; we can just use r0 instead of re-loading from the struct.
.org 0x800E1E14
  mr r3, r0 ; r0 already has the target ptr from static buffer
  nop       ; skip the lwz

; F32 read (for increment on NULL target): File 0xDED78: lbz r4, 0xF32(r31)
.org 0x800E1E38
  b setAimPos_state_read2_trampoline
.org @NextFreeSpace
.global setAimPos_state_read2_trampoline
setAimPos_state_read2_trampoline:
  lis r4, boomerang_lock_state@ha
  addi r4, r4, boomerang_lock_state@l
  lbz r4, 0 (r4)
  b 0x800E1E3C

; F32 store (increment): File 0xDED80: stb r0, 0xF32(r31)
.org 0x800E1E40
  b setAimPos_state_store_trampoline
.org @NextFreeSpace
.global setAimPos_state_store_trampoline
setAimPos_state_store_trampoline:
  stb r0, 0xF32 (r31) ; keep struct write
  lis r4, boomerang_lock_state@ha
  addi r4, r4, boomerang_lock_state@l
  stb r0, 0 (r4)      ; also write to static
  b 0x800E1E44

; F31 read (loop condition): File 0xDED8C: lbz r0, 0xF31(r31)
.org 0x800E1E4C
  b setAimPos_count_trampoline
.org @NextFreeSpace
.global setAimPos_count_trampoline
setAimPos_count_trampoline:
  lis r12, boomerang_lock_count@ha
  addi r12, r12, boomerang_lock_count@l
  lbz r0, 0 (r12)
  b 0x800E1E50

; ============================================================================
; procWait patches
; F32 store (reset to 0): File 0xDEF54: stb r3, 0xF32(r30) where r3=0
; ============================================================================
.org 0x800E2014
  b procWait_state_store_trampoline
.org @NextFreeSpace
.global procWait_state_store_trampoline
procWait_state_store_trampoline:
  stb r3, 0xF32 (r30) ; keep struct write
  lis r4, boomerang_lock_state@ha
  addi r4, r4, boomerang_lock_state@l
  stb r3, 0 (r4)      ; also write to static
  b 0x800E2018

; F32 read (after setAimPos): File 0xDEF60: lbz r3, 0xF32(r30)
.org 0x800E2020
  b procWait_state_read_trampoline
.org @NextFreeSpace
.global procWait_state_read_trampoline
procWait_state_read_trampoline:
  lis r3, boomerang_lock_state@ha
  addi r3, r3, boomerang_lock_state@l
  lbz r3, 0 (r3)
  b 0x800E2024

; F31 read (comparison with F32): File 0xDEF64: lbz r0, 0xF31(r30)
.org 0x800E2024
  b procWait_count_read_trampoline
.org @NextFreeSpace
.global procWait_count_read_trampoline
procWait_count_read_trampoline:
  lis r12, boomerang_lock_count@ha
  addi r12, r12, boomerang_lock_count@l
  lbz r0, 0 (r12)
  b 0x800E2028

; ============================================================================
; procMove distance-based arrival check (0x800E2640, disasm 0xDF580)
; Original: lfs f0, 0x254(r31); fcmpo cr0, f31, f0; blt 0xdf5bc
; The blt target (0xdf5bc = 0x800E267C) is inside our NOP'd target visit
; block. We must handle "arrived at destination" here instead, setting F2E,
; incrementing state, and CRITICALLY clearing F36 (which guards the count
; check). Without clearing F36, the 0-target free-aim return never triggers.
; ============================================================================
.org 0x800E2640
  b procMove_distance_check
  nop ; was fcmpo at 0x800E2644 (df584)
  nop ; was blt at 0x800E2648 (df588)

.org @NextFreeSpace
.global procMove_distance_check
procMove_distance_check:
  lfs f0, 0x254 (r31)
  fcmpo cr0, f31, f0
  blt procMove_arrived_handler
  b 0x800E264C ; not arrived → continue to collision check (df58c)

.global procMove_arrived_handler
procMove_arrived_handler:
  ; Set F2E = 1 (arrived/hit flag)
  li r0, 1
  stb r0, 0xF2E (r31)

  ; Clear current target ptr and ID in static buffers
  lis r4, boomerang_lock_state@ha
  addi r4, r4, boomerang_lock_state@l
  lbz r3, 0 (r4)              ; current state/index
  slwi r5, r3, 2              ; byte offset

  li r0, 0
  lis r6, boomerang_lock_ptrs@ha
  addi r6, r6, boomerang_lock_ptrs@l
  stwx r0, r6, r5             ; clear ptr

  li r8, -1
  lis r6, boomerang_lock_ids@ha
  addi r6, r6, boomerang_lock_ids@l
  stwx r8, r6, r5             ; invalidate ID

  ; Also clear in struct (if index < 5)
  cmplwi r3, 5
  bge procMove_arrived_skip_struct
  add r5, r31, r5
  stw r0, 0xF18 (r5)
  stw r8, 0xF04 (r5)
procMove_arrived_skip_struct:

  ; Increment state
  lis r4, boomerang_lock_state@ha
  addi r4, r4, boomerang_lock_state@l
  lbz r3, 0 (r4)
  addi r3, r3, 1
  stb r3, 0 (r4)               ; static
  stb r3, 0xF32 (r31)          ; struct

  ; Clear F36 (critical: allows count check to run on next flag check)
  li r0, 0
  stb r0, 0xF36 (r31)

  b 0x800E26BC ; jump to flag checks (df5fc)

; ============================================================================
; procMove target visit block (0x800E2664 to 0x800E26B8)
; This contiguous block reads F32, accesses F18[F32] and F04[F32],
; increments F32, etc. Replace the entire block.
;
; Verified addresses from main.asm (disasm + 0x800030C0 = virtual):
; 0x800E2664 (disasm 0xDF5A4): lbz r0, 0xF32(r31) - start of block
; 0x800E26B8 (disasm 0xDF5F8): stb r5, 0xF36(r31) - end of block
; Returns to 0x800E26BC (disasm 0xDF5FC)
; ============================================================================
.org 0x800E2664
  b procMove_target_visit_custom
  ; Fill remaining space with nops (0x800E2668 to 0x800E26B8 = 21 instructions)
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
.org @NextFreeSpace
.global procMove_target_visit_custom
procMove_target_visit_custom:
  ; r3 = return value from previous function call (colliding actor ptr or NULL)
  ; r31 = this (daBoomerang_c*)
  ; r5 = 0 (set before this block in some paths)
  ; We need to check if r3 matches the current target's ptr.

  ; Load current target index from static buffer
  lis r4, boomerang_lock_state@ha
  addi r4, r4, boomerang_lock_state@l
  lbz r0, 0 (r4)         ; r0 = current target index

  ; Load current target ptr from static buffer
  slwi r4, r0, 2
  lis r6, boomerang_lock_ptrs@ha
  addi r6, r6, boomerang_lock_ptrs@l
  lwzx r4, r6, r4        ; r4 = target_ptr[current_index]

  ; Compare colliding actor (r3) with current target ptr
  cmplw r3, r4
  bne procMove_target_visit_end ; not the current target

  ; Match! Set the hit flag
  li r4, 1
  stb r4, 0xF2E (r31)

  ; Clear current target ptr and ID in static buffers
  slwi r4, r0, 2
  li r5, 0
  stwx r5, r6, r4        ; clear ptr in static
  lis r6, boomerang_lock_ids@ha
  addi r6, r6, boomerang_lock_ids@l
  li r8, -1
  stwx r8, r6, r4        ; invalidate ID in static

  ; Also clear in struct (if index < 5)
  cmplwi r0, 5
  bge procMove_skip_struct_clear
  add r4, r31, r4        ; r4 still has index*4
  stw r5, 0xF18 (r4)
  stw r8, 0xF04 (r4)
procMove_skip_struct_clear:

  ; Increment current target index
  lis r4, boomerang_lock_state@ha
  addi r4, r4, boomerang_lock_state@l
  lbz r6, 0 (r4)
  addi r6, r6, 1
  stb r6, 0 (r4)         ; write to static
  stb r6, 0xF32 (r31)    ; write to struct

  ; Clear secondary flag
  li r5, 0
  stb r5, 0xF36 (r31)

procMove_target_visit_end:
  b 0x800E26BC ; continue after the block

; ============================================================================
; procMove count/index comparison (checks if all targets visited)
; 0x800E26E0 (disasm 0xDF620): lbz r3, 0xF31(r31) - lock count
; 0x800E26E4 (disasm 0xDF624): lbz r0, 0xF32(r31) - current index
; ============================================================================
.org 0x800E26E0
  b procMove_count_cmp_trampoline
  nop
.org @NextFreeSpace
.global procMove_count_cmp_trampoline
procMove_count_cmp_trampoline:
  lis r3, boomerang_lock_count@ha
  addi r3, r3, boomerang_lock_count@l
  lbz r3, 0 (r3)
  lis r12, boomerang_lock_state@ha
  addi r12, r12, boomerang_lock_state@l
  lbz r0, 0 (r12)
  b 0x800E26E8 ; return to cmplw r3, r0

; ============================================================================
; execute loop patches (0x800E2AF4)
; The execute function has a loop that re-resolves actor IDs to pointers.
; It reads F04[i] and writes F18[i] for each target.
; ============================================================================

; Rewrite the loop body to use static buffers.
; Loop setup: File 0xDFA5C: b 0xDFA84 (jump to condition)
; Loop body at 0xDFA60-0xDFA8C:
;   0x800E2B20: add r29, r27, r31     ; r29 = this + byte_offset
;   0x800E2B24: lwz r0, 0xF04(r29)    ; load ID
;   0x800E2B28: stw r0, 8(r1)         ; store on stack
;   0x800E2B2C: mr r3, r30            ; context
;   0x800E2B30: addi r4, r1, 8        ; ptr to ID
;   0x800E2B34: bl resolve_id         ; resolve
;   0x800E2B38: stw r3, 0xF18(r29)    ; store ptr
;   0x800E2B3C: addi r28, r28, 1      ; counter++
;   0x800E2B40: addi r31, r31, 4      ; byte_offset += 4
;   0x800E2B44: lbz r0, 0xF31(r27)    ; lock count
;   0x800E2B48: cmpw r28, r0          ; compare
;   0x800E2B4C: blt loop_body

; Patch the initial jump-to-condition (0x800E2B1C) to use our custom entry
; Original: b 0x800E2B44 (skips to condition check, which is now NOP'd)
.org 0x800E2B1C
  b execute_loop_entry

; Patch loop body entry (0x800E2B20) to branch to custom code
.org 0x800E2B20
  b execute_loop_custom
  nop
  nop
  nop
  nop
  nop ; bl resolve_id (0x800E2B34) - keep this, will call from custom
  nop
  nop
  nop
  nop
  nop
  nop
.org @NextFreeSpace
.global execute_loop_custom
execute_loop_custom:
  ; r27 = this, r28 = loop counter, r30 = context, r31 = byte offset
  ; Load ID from static buffer instead of struct
  lis r29, boomerang_lock_ids@ha
  addi r29, r29, boomerang_lock_ids@l
  lwzx r0, r29, r31      ; load ID at byte offset
  stw r0, 8 (sp)          ; store on stack
  mr r3, r30              ; context
  addi r4, sp, 8          ; ptr to ID
  bl fopAcIt_Judge__FPFPvPv_PvPv ; resolve actor ID to pointer
  ; Store resolved ptr in static buffer
  lis r29, boomerang_lock_ptrs@ha
  addi r29, r29, boomerang_lock_ptrs@l
  stwx r3, r29, r31      ; store ptr at byte offset

  ; Also store in struct (if index < 5)
  cmplwi r28, 5
  bge execute_skip_struct_write
  add r29, r27, r31
  stw r3, 0xF18 (r29)
execute_skip_struct_write:

  ; Increment counters
  addi r28, r28, 1
  addi r31, r31, 4

  ; Load count from static buffer and compare
  lis r12, boomerang_lock_count@ha
  addi r12, r12, boomerang_lock_count@l
  lbz r0, 0 (r12)
  cmpw r28, r0
  blt execute_loop_custom ; loop

  b 0x800E2B50 ; continue after loop (next instruction after original blt)

; Entry point for the loop - checks condition before first iteration (while-loop pattern)
.org @NextFreeSpace
.global execute_loop_entry
execute_loop_entry:
  lis r12, boomerang_lock_count@ha
  addi r12, r12, boomerang_lock_count@l
  lbz r0, 0 (r12)
  cmpw r28, r0
  blt execute_loop_custom
  b 0x800E2B50 ; no targets, skip loop

.close
