; Patches to support Phantom Ganon (type 0) fighting on the open ocean surface.

; --- Patch 1: Remove Y-height gate in move() ---
; In vanilla, move() checks if the player's Y position is below 710.0 for type 0.
; If so, PG either disappears (mAction==0) or resets to mAction=2 (otherwise).
; On the ocean surface (Y≈0), this would cause PG to immediately disappear.
; Fix: Skip the entire Y-height check block by making the type!=0 branch unconditional.
; Source: d_a_fganon.cpp lines 1546-1555

.open "files/rels/d_a_fganon.rel"
.org 0x6434
  ; Was: bne 0x6498 (skip Y-height block only for type != 0)
  ; Now: always skip Y-height block
  b 0x6498
.close


; --- Patch 2: Make down() treat ocean surface as landing for type 0 ---
; Problem over ocean:
; - mode 1 in down() never sees ChkGroundHit() true, so PG stays invulnerable.
; - PG can sink below the water plane while in down().
; - GroundCross-based "landed" logic can immediately force kieru over water.
;
; Fix:
; - In mode 1 ground check, if type==0 and Y<=0.0, treat as landed.
; - Clamp type 0 PG to Y>=0.0 during down() and zero Y speed at surface.
; - Skip GroundCross-based immediate kieru logic for type 0.
; Source: d_a_fganon.cpp down() lines 763-812.

.open "files/rels/d_a_fganon.rel"
.org 0x380C
  ; Hook mode 1's ChkGroundHit gate.
  b ocean_down_mode1_ground_check

.org 0x3994
  ; Hook right before GroundCross logic to clamp to ocean surface.
  b ocean_down_surface_clamp

.org 0x3AF4
  ; For type 0, skip GroundCross-based "landed" detection. Ocean/water collision can
  ; trip this immediately and force kieru without a stun window.
  b ocean_down_groundcross_gate

.org @NextFreeSpace
.global ocean_down_mode1_ground_check
ocean_down_mode1_ground_check:
  ; Recreate overwritten instructions from 0x380C:
  ;   lwz r0, 0x0720(r31)
  ;   rlwinm. r0, r0, 0, 26, 26
  lwz r0, 0x0720 (r31)
  rlwinm. r0, r0, 0, 26, 26
  bne ocean_down_mode1_ground_check_landed

  ; If not grounded by Acch, special-case type 0 on ocean surface.
  lbz r12, 0x02BC (r31)
  cmpwi r12, 0
  bne ocean_down_mode1_ground_check_not_landed

  lfs f1, 0x01FC (r31) ; current.pos.y
  li r12, 0
  stw r12, 0x34 (r1)
  lfs f0, 0x34 (r1) ; 0.0
  fcmpo cr0, f1, f0
  bgt ocean_down_mode1_ground_check_not_landed

ocean_down_mode1_ground_check_landed:
  b 0x3818 ; Continue as if grounded.

ocean_down_mode1_ground_check_not_landed:
  b 0x3870 ; Original beq target.

.global ocean_down_groundcross_gate
ocean_down_groundcross_gate:
  ; Continue vanilla no-ground behavior.
  beq ocean_down_groundcross_gate_skip

  ; For type 0 (ocean fight), don't treat GroundCross as an immediate disappear
  ; condition. Let the stun window logic run instead.
  lbz r12, 0x02BC (r31)
  cmpwi r12, 0
  beq ocean_down_groundcross_gate_skip

  ; Non-type0: run vanilla compare path starting at 0x3AF8.
  b 0x3AF8

ocean_down_groundcross_gate_skip:
  b 0x3B0C

.global ocean_down_surface_clamp
ocean_down_surface_clamp:
  ; Restore overwritten instruction from 0x3994.
  li r17, 0

  ; Clamp type 0 to ocean surface so he doesn't sink during down().
  lbz r12, 0x02BC (r31)
  cmpwi r12, 0
  bne ocean_down_surface_clamp_return

  lfs f1, 0x01FC (r31) ; current.pos.y
  li r12, 0
  stw r12, 0x34 (r1)
  lfs f0, 0x34 (r1) ; 0.0
  fcmpo cr0, f1, f0
  bge ocean_down_surface_clamp_return

  stfs f0, 0x01FC (r31) ; current.pos.y = 0.0
  stfs f0, 0x0224 (r31) ; speed.y = 0.0

ocean_down_surface_clamp_return:
  b 0x3998
.close


; --- Patch 3: Stabilize player state during defeat demo teleports ---
; The defeat demo teleports Link near PG each frame. On ocean, Link can still have
; SHIP_RIDE or SWIM status active, causing movement systems to fight the teleport and
; making Link jitter/vibrate.
; Fix:
; - In case 50 init, set player demo param0=3 and demo mode=DEMO_INIT_WAIT so
;   player code clears SHIP_RIDE via its normal demo-init path.
; - Before the case 51 / case 52 player teleports, clear SHIP_RIDE/SWIM status bits.
; Source: d_a_fganon.cpp lines around 1791 and 1817.

.open "files/rels/d_a_fganon.rel"
.org 0x6AD8
  ; In case 50 init, replace mDemo.param0 = 0 with custom setup that:
  ; - sets param0=3 (player code clears SHIP_RIDE in DEMO_INIT_WAIT path)
  ; - sets demo mode to DEMO_INIT_WAIT (4)
  b fganon_demo_prepare_player_for_case50

.org 0x6BC4
  b fganon_demo_clear_ship_swim_status_case51

.org 0x6C8C
  b fganon_demo_clear_ship_swim_status_case52

.org @NextFreeSpace
.global fganon_demo_prepare_player_for_case50
fganon_demo_prepare_player_for_case50:
  ; Original at 0x6AD8 was: stw r3, 0x030C(r21) with r3=0.
  ; Set param0 to 3 instead so player demo init clears SHIP_RIDE.
  stw r0, 0x030C (r21)

  ; DEMO_INIT_WAIT_e = 4
  li r12, 4
  stw r12, 0x0314 (r21)

  b 0x6ADC

.global fganon_demo_clear_ship_swim_status_core
fganon_demo_clear_ship_swim_status_core:
  ; playerStatus0[0] is at g_dComIfG_gameInfo + 0x5CC8.
  ; Clear bits: SHIP_RIDE(0x00010000) | SWIM(0x00100000).
  lis r12, 0x803C
  addi r12, r12, 0x4C08
  lwz r11, 0x5CC8 (r12)
  lis r10, 0xFFEE
  ori r10, r10, 0xFFFF
  and r11, r11, r10
  stw r11, 0x5CC8 (r12)
  blr

.global fganon_demo_clear_ship_swim_status_case51
fganon_demo_clear_ship_swim_status_case51:
  bl fganon_demo_clear_ship_swim_status_core
  ; Restore overwritten instruction from 0x6BC4.
  mr r3, r21
  b 0x6BC8

.global fganon_demo_clear_ship_swim_status_case52
fganon_demo_clear_ship_swim_status_case52:
  bl fganon_demo_clear_ship_swim_status_core
  ; Restore overwritten instruction from 0x6C8C.
  mr r3, r21
  b 0x6C90
.close
