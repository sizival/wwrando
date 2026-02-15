; Repurpose Iron Boots as Water Boots behavior:
; - Keep the original Gecko walk-on-water logic bytes.
; - Use a custom Water Boots on/off flag (not the heavy-boots flag).
; - Keep heavy-boots gameplay behavior disabled.
; - Triple walk-on-water speed while Water Boots are active.

.open "sys/main.dol"

; Gecko custom stub #1 (left byte-identical to original).
.org 0x80004010
  .int 0x2C070003
  .int 0xC01EFFA0
  .int 0x4182000C
  .int 0xC01F008C
  .int 0x4809EF60
  .int 0xFC16A840
  .int 0xC2DEFFA4
  .int 0x4182FFF0
  .int 0x4809EF54

; Gecko custom stub #2 (left byte-identical to original).
.org 0x80004048
  .int 0x281E5787
  .int 0x4081001C
  .int 0xFC010040
  .int 0x4080000C
  .int 0xD2BEFFA0
  .int 0x4800000C
  .int 0xC2DEFF9C
  .int 0xD03EFFA0
  .int 0xEC210028
  .int 0x48138FB8

; NOTE:
; Gecko writes to 0x803C5E44 (RAM), but that address is not part of any
; serialized DOL section, so we can't patch it directly with .org.
; Instead we perform the same write at runtime before entering Gecko logic.

; In dBgS_Acch::GroundCheck, route to a wrapper that conditionally runs
; walk-on-water behavior only when Water Boots are active.
.org 0x800A2F7C
  b water_boots_groundcheck_wrapper

; In daPy_lk_c::changeSwimProc, route to a wrapper that conditionally runs
; walk-on-water behavior only when Water Boots are active.
.org 0x8013D020
  b water_boots_change_swim_wrapper

; In daPy_lk_c::checkNewItemChange, allow boots toggling while swimming by
; bypassing the ground-hit gate only for Iron/Water Boots item IDs.
.org 0x8010CDEC
  b water_boots_item_change_groundcheck_wrapper

; In daPy_lk_c::checkItemChangeFromButton, allow boot button triggers to pass
; the initial mode-flag gate so they can reach the existing X/Y/Z item logic.
.org 0x8010CFC8
  b water_boots_item_change_modeflag_wrapper

; In daPy_lk_c::procBootsEquip, replace heavy-boots flag toggle with
; Water Boots custom flag toggle.
.org 0x80119910
  b water_boots_toggle_wrapper

; In daPy_lk_c::setNormalSpeedF, triple ground speed while Water Boots are
; active and Link is walking on water (in water but not in swim mode).
.org 0x80108C08
  b water_boots_walk_speed_wrapper

; In daPy_lk_c::setBootsModel, use Water Boots custom flag for visual model
; setup instead of heavy-boots gameplay flag.
.org 0x80105830
  b water_boots_visual_check_setbootsmodel

; In daPy_lk_c::setItemModel, use Water Boots custom flag for boot model
; matrix setup/audio selection instead of heavy-boots gameplay flag.
.org 0x801065AC
  b water_boots_visual_check_setitemmodel

; In daPy_lk_c::draw, use Water Boots custom flag for rendering the boot
; models instead of heavy-boots gameplay flag.
.org 0x80107D6C
  b water_boots_visual_check_draw

; In daPy_lk_c::setItemModel active-boots branch, force normal boots audio type.
; Vanilla uses li r4,1 before setLinkBootsType when heavy boots are equipped.
; We keep Water Boots visuals but suppress Iron Boots-specific boots audio.
.org 0x801065C8
  li r4, 0

; In dMeter_Execute, before writing mButtonMode, force X/Y/Z button-enable bits
; for slots that have Water/Iron Boots while Link is in water.
.org 0x80204BD4
  b water_boots_meter_button_mode_wrapper

; In dMeter_xyAlpha, bypass the swim-only forced-gray branch when any X/Y/Z
; slot has Water/Iron Boots selected.
.org 0x801F61B8
  b water_boots_meter_swim_graycheck_wrapper

; In dMeter_xyAlpha per-slot disallow fallback, treat Water/Iron Boots as
; allowed so the icon stays fully lit and button bits are set.
.org 0x801F6704
  b water_boots_meter_force_allow_wrapper

.org @NextFreeSpace
.global water_boots_groundcheck_wrapper
water_boots_groundcheck_wrapper:
  ; Only active when custom Water Boots flag is on.
  lis r12, water_boots_active@ha
  addi r12, r12, water_boots_active@l
  lbz r12, 0 (r12)
  cmpwi r12, 0
  beq water_boots_groundcheck_vanilla

  ; Water Boots active: run Gecko custom logic.
  bl write_walk_on_water_ram_value
  b 0x80004010

water_boots_groundcheck_vanilla:
  ; Restore overwritten vanilla instruction and return.
  lfs f0, 0x008C (r31)
  b 0x800A2F80

.global water_boots_change_swim_wrapper
water_boots_change_swim_wrapper:
  ; Only active when custom Water Boots flag is on.
  lis r12, water_boots_active@ha
  addi r12, r12, water_boots_active@l
  lbz r12, 0 (r12)
  cmpwi r12, 0
  beq water_boots_change_swim_vanilla

  ; Water Boots active: run Gecko custom logic.
  bl write_walk_on_water_ram_value
  b 0x80004048

water_boots_change_swim_vanilla:
  ; Restore overwritten vanilla instruction and return.
  fsubs f1, f1, f0
  b 0x8013D024

.global water_boots_toggle_wrapper
water_boots_toggle_wrapper:
  ; Toggle custom Water Boots flag.
  lis r12, water_boots_active@ha
  addi r12, r12, water_boots_active@l
  lbz r11, 0 (r12)
  xori r11, r11, 1
  stb r11, 0 (r12)

  ; Always clear heavy-boots equip flag to remove Iron Boots gameplay behavior.
  lwz r0, 0x029C (r30)
  rlwinm r0, r0, 0, 7, 5
  stw r0, 0x029C (r30)

  ; If toggled on while in water, pop Link to the water surface.
  cmpwi r11, 0
  beq water_boots_toggle_done
  lwz r0, 0x029C (r30)
  rlwinm. r0, r0, 0, 24, 24
  beq water_boots_toggle_done
  lfs f0, 0x35D0 (r30) ; Water surface Y (m35D0)
  stfs f0, 0x01FC (r30) ; current.pos.y
  stfs f0, 0x01E8 (r30) ; old.pos.y

water_boots_toggle_done:

  ; Return right after the original heavy-boots toggle block so vanilla
  ; procBootsEquip transition/effect logic still runs.
  b 0x80119938

.global water_boots_item_change_groundcheck_wrapper
water_boots_item_change_groundcheck_wrapper:
  ; r30 = selected item ID in checkNewItemChange.
  cmplwi r30, 0x29 ; dItem_IRON_BOOTS_e
  beq water_boots_item_change_allow
  cmplwi r30, 0x2B ; WATER_BOOTS
  beq water_boots_item_change_allow

  ; Non-boots: preserve vanilla ground-hit gate.
  lwz r0, 0x0494 (r31)
  rlwinm. r0, r0, 0, 26, 26
  bne water_boots_item_change_groundcheck_continue
  b 0x8010CF0C
water_boots_item_change_groundcheck_continue:
  b 0x8010CDF8

water_boots_item_change_allow:
  ; Skip the ground/fly gate and enter boots handling directly.
  b 0x8010CE0C

.global water_boots_meter_button_mode_wrapper
water_boots_meter_button_mode_wrapper:
  ; Original instruction.
  lbz r0, 0x3024 (r30)

  ; Use game-info play state to check selected items.
  lis r3, g_dComIfG_gameInfo@ha
  addi r3, r3, g_dComIfG_gameInfo@l

  ; mSelectItem[0..2] at play offset 0x4933 => absolute +0x5BD3.
  lbz r11, 0x5BD3 (r3)
  cmplwi r11, 0x29 ; dItem_IRON_BOOTS_e
  beq water_boots_meter_enable_x
  cmplwi r11, 0x2B ; WATER_BOOTS
  bne water_boots_meter_check_y
water_boots_meter_enable_x:
  ori r0, r0, 0x0004 ; BTN_X

water_boots_meter_check_y:
  lbz r11, 0x5BD4 (r3)
  cmplwi r11, 0x29 ; dItem_IRON_BOOTS_e
  beq water_boots_meter_enable_y
  cmplwi r11, 0x2B ; WATER_BOOTS
  bne water_boots_meter_check_z
water_boots_meter_enable_y:
  ori r0, r0, 0x0008 ; BTN_Y

water_boots_meter_check_z:
  lbz r11, 0x5BD5 (r3)
  cmplwi r11, 0x29 ; dItem_IRON_BOOTS_e
  beq water_boots_meter_enable_z
  cmplwi r11, 0x2B ; WATER_BOOTS
  bne water_boots_meter_button_mode_done
water_boots_meter_enable_z:
  ori r0, r0, 0x0020 ; BTN_Z

water_boots_meter_button_mode_done:
  b 0x80204BD8

.global water_boots_item_change_modeflag_wrapper
water_boots_item_change_modeflag_wrapper:
  ; Restore overwritten mode-flag gate.
  lwz r0, 0x3618 (r3)
  rlwinm. r0, r0, 0, 29, 29
  bne water_boots_item_change_modeflag_continue

  ; Mode flag is not set: allow boot triggers on X/Y/Z to continue.
  lbz r5, 0x34C8 (r31) ; mItemTrigger bitfield
  lis r3, g_dComIfG_gameInfo@ha
  addi r3, r3, g_dComIfG_gameInfo@l

  ; X trigger (BTN_X bit) + boots selected on X.
  rlwinm. r0, r5, 0, 29, 29
  beq water_boots_item_change_modeflag_check_y
  lbz r4, 0x5BD3 (r3)
  cmplwi r4, 0x29 ; dItem_IRON_BOOTS_e
  beq water_boots_item_change_modeflag_allow
  cmplwi r4, 0x2B ; WATER_BOOTS
  beq water_boots_item_change_modeflag_allow

water_boots_item_change_modeflag_check_y:
  ; Y trigger (BTN_Y bit) + boots selected on Y.
  rlwinm. r0, r5, 0, 28, 28
  beq water_boots_item_change_modeflag_check_z
  lbz r4, 0x5BD4 (r3)
  cmplwi r4, 0x29 ; dItem_IRON_BOOTS_e
  beq water_boots_item_change_modeflag_allow
  cmplwi r4, 0x2B ; WATER_BOOTS
  beq water_boots_item_change_modeflag_allow

water_boots_item_change_modeflag_check_z:
  ; Z trigger (BTN_Z bit) + boots selected on Z.
  rlwinm. r0, r5, 0, 27, 27
  beq water_boots_item_change_modeflag_deny
  lbz r4, 0x5BD5 (r3)
  cmplwi r4, 0x29 ; dItem_IRON_BOOTS_e
  beq water_boots_item_change_modeflag_allow
  cmplwi r4, 0x2B ; WATER_BOOTS
  beq water_boots_item_change_modeflag_allow

water_boots_item_change_modeflag_deny:
  ; Match vanilla early-return path when mode flag fails.
  b 0x8010D254

water_boots_item_change_modeflag_allow:
  ; Continue checkItemChangeFromButton after the mode-flag gate.
  ; Restore this pointer in r3 before re-entering vanilla flow.
  mr r3, r31
  b 0x8010CFD4

water_boots_item_change_modeflag_continue:
  ; Mode flag passed: continue vanilla flow.
  b 0x8010CFD4

.global water_boots_meter_swim_graycheck_wrapper
water_boots_meter_swim_graycheck_wrapper:
  ; Restore overwritten swim-status check (dMtrStts_UNK2000_e).
  rlwinm. r0, r3, 0, 18, 18
  beq water_boots_meter_swim_graycheck_continue

  ; Swimming: if any slot has Water/Iron Boots, skip the forced-gray branch.
  lis r12, g_dComIfG_gameInfo@ha
  addi r12, r12, g_dComIfG_gameInfo@l

  lbz r4, 0x5BD3 (r12)
  cmplwi r4, 0x29 ; dItem_IRON_BOOTS_e
  beq water_boots_meter_swim_graycheck_continue
  cmplwi r4, 0x2B ; WATER_BOOTS
  beq water_boots_meter_swim_graycheck_continue

  lbz r4, 0x5BD4 (r12)
  cmplwi r4, 0x29 ; dItem_IRON_BOOTS_e
  beq water_boots_meter_swim_graycheck_continue
  cmplwi r4, 0x2B ; WATER_BOOTS
  beq water_boots_meter_swim_graycheck_continue

  lbz r4, 0x5BD5 (r12)
  cmplwi r4, 0x29 ; dItem_IRON_BOOTS_e
  beq water_boots_meter_swim_graycheck_continue
  cmplwi r4, 0x2B ; WATER_BOOTS
  beq water_boots_meter_swim_graycheck_continue

  ; No boots selected: preserve vanilla forced-gray behavior.
  b 0x801F61D8

water_boots_meter_swim_graycheck_continue:
  b 0x801F61C0

.global water_boots_meter_force_allow_wrapper
water_boots_meter_force_allow_wrapper:
  ; Check current slot index (r28) selected item in play.mSelectItem[0..2].
  lis r12, g_dComIfG_gameInfo@ha
  addi r12, r12, g_dComIfG_gameInfo@l
  add r12, r12, r28
  lbz r4, 0x5BD3 (r12)
  cmplwi r4, 0x29 ; dItem_IRON_BOOTS_e
  beq water_boots_meter_force_allow
  cmplwi r4, 0x2B ; WATER_BOOTS
  beq water_boots_meter_force_allow

  ; Non-boots: preserve vanilla per-slot gray fallback.
  addi r3, r13, -32164
  b 0x801F6708

water_boots_meter_force_allow:
  ; Route to vanilla "allowed item" block for this slot.
  b 0x801F673C

.global water_boots_walk_speed_wrapper
water_boots_walk_speed_wrapper:
  ; Check custom Water Boots toggle.
  lis r12, water_boots_active@ha
  addi r12, r12, water_boots_active@l
  lbz r11, 0 (r12)
  cmpwi r11, 0
  beq water_boots_walk_speed_continue

  ; Require water-contact state (daPyFlg0_UNK80).
  lwz r11, 0x029C (r31)
  rlwinm. r11, r11, 0, 24, 24
  beq water_boots_walk_speed_continue

  ; Do not affect swim mode.
  lwz r11, 0x3618 (r31)
  rlwinm. r11, r11, 0, 13, 13
  bne water_boots_walk_speed_continue

  ; Require grounded movement so this does not apply in midair.
  ; dBgS_Acch::GROUND_HIT is bit 0x20 at mAcch.m_flags (0x046C + 0x28 = 0x0494).
  lwz r11, 0x0494 (r31)
  andi. r11, r11, 0x0020
  beq water_boots_walk_speed_continue

  ; Require water surface to be at/above ground height (over-water context).
  ; m35D0 is water Y, mAcch.m_ground_h is at 0x046C + 0x94 = 0x0500.
  lfs f1, 0x35D0 (r31)
  lfs f0, 0x0500 (r31)
  fcmpo cr0, f1, f0
  blt water_boots_walk_speed_continue

  ; Triple the computed normal speed for walk-on-water movement.
  lis r12, water_boots_walk_speed_multiplier@ha
  addi r12, r12, water_boots_walk_speed_multiplier@l
  lfs f0, 0 (r12)
  fmuls f31, f31, f0

water_boots_walk_speed_continue:
  ; Restore overwritten instruction and return.
  lwz r0, 0x0314 (r31)
  b 0x80108C0C

.global water_boots_visual_check_setbootsmodel
water_boots_visual_check_setbootsmodel:
  lis r12, water_boots_active@ha
  addi r12, r12, water_boots_active@l
  lbz r12, 0 (r12)
  cmpwi r12, 0
  bne water_boots_visual_check_setbootsmodel_active
  b 0x8010587C
water_boots_visual_check_setbootsmodel_active:
  b 0x8010583C

.global water_boots_visual_check_setitemmodel
water_boots_visual_check_setitemmodel:
  lis r12, water_boots_active@ha
  addi r12, r12, water_boots_active@l
  lbz r12, 0 (r12)
  cmpwi r12, 0
  bne water_boots_visual_check_setitemmodel_active
  b 0x801065D4
water_boots_visual_check_setitemmodel_active:
  b 0x801065B8

.global water_boots_visual_check_draw
water_boots_visual_check_draw:
  lis r12, water_boots_active@ha
  addi r12, r12, water_boots_active@l
  lbz r12, 0 (r12)
  cmpwi r12, 0
  bne water_boots_visual_check_draw_active
  b 0x80107DA0
water_boots_visual_check_draw_active:
  b 0x80107D78

.global write_walk_on_water_ram_value
write_walk_on_water_ram_value:
  ; Equivalent of Gecko: 043C5E44 04071987
  lis r11, 0x0407
  ori r11, r11, 0x1987
  lis r12, 0x803C
  stw r11, 0x5E44 (r12)
  blr

.global water_boots_active
water_boots_active:
  .byte 0
  .balign 4

water_boots_walk_speed_multiplier:
  .float 3.0

.close
