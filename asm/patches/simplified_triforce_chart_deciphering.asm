; This patch implements the "Simplified Triforce Chart Deciphering" option.
;
; In vanilla, Tingle deciphers a single Triforce Chart (the lowest-numbered owned undeciphered
; one) for 398 Rupees, and must be paid again for each additional chart.
; With this patch, paying Tingle 398 Rupees once deciphers every Triforce Chart the player
; currently owns, and any Triforce Chart obtained afterwards is deciphered automatically the
; moment it is picked up.
;
; To remember that the player has paid, we repurpose event bit 6B40 (bit mask 0x40 of byte
; 803C5297), which was unused in the base game.
; This patch is only applied when the option is enabled, so vanilla behavior is untouched otherwise.
;
; Addresses used:
;   803C4CCC = dSv_player_map_c within the save data (g_dComIfG_gameInfo.save.player.mMap)
;   803C522C = dSv_event_c within the save data (g_dComIfG_gameInfo.save.mEvent)

.open "sys/main.dol"

; Replacement for daNpc_Tc_c::analysisCollectMap's behavior (reached via the branch we patch
; into d_a_npc_tc.rel below, inside daNpc_Tc_c::cutPresentProc).
; Vanilla analysisCollectMap deciphers only the first owned undeciphered Triforce Chart and
; returns its number (1-8) so the present cutscene shows that chart's deciphered item.
; Our version deciphers ALL owned undeciphered charts, sets the event bit for having paid, and
; still returns the number of the first chart it deciphered so the presented item is unchanged.
.org @NextFreeSpace
.global simplified_decipher_all_owned_charts
simplified_decipher_all_owned_charts:
  stwu sp, -0x20 (sp)
  mflr r0
  stw r0, 0x24 (sp)
  stw r31, 0x1C (sp)
  stw r30, 0x18 (sp)

  li r31, 0 ; The first owned undeciphered chart number we find (the return value; 0 if none)
  li r30, 1 ; The current chart number (1-8)

simplified_decipher_loop_start:
  lis r3, 0x803C4CCC@ha
  addi r3, r3, 0x803C4CCC@l
  addi r4, r30, -1 ; Triforce Charts are collect maps 1-8, and the save functions take a 0-indexed argument
  bl isGetMap__16dSv_player_map_cFi
  cmpwi r3, 0
  beq simplified_decipher_loop_continue ; The player doesn't own this chart

  lis r3, 0x803C4CCC@ha
  addi r3, r3, 0x803C4CCC@l
  addi r4, r30, -1
  bl isTriforce__16dSv_player_map_cFi
  cmpwi r3, 0
  bne simplified_decipher_loop_continue ; This chart is already deciphered

  cmpwi r31, 0
  bne simplified_decipher_not_first
  mr r31, r30 ; Remember the first chart we decipher so Tingle presents its item
simplified_decipher_not_first:

  lis r3, 0x803C4CCC@ha
  addi r3, r3, 0x803C4CCC@l
  addi r4, r30, -1
  bl onTriforce__16dSv_player_map_cFi ; Set this chart's deciphered bit

simplified_decipher_loop_continue:
  addi r30, r30, 1
  cmpwi r30, 8
  ble simplified_decipher_loop_start

  ; Set the event bit for having paid Tingle, so charts obtained later are deciphered on pickup.
  lis r3, 0x803C522C@ha
  addi r3, r3, 0x803C522C@l
  li r4, 0x6B40 ; Unused event bit we use for having paid for Simplified Triforce Chart Deciphering
  bl onEventBit__11dSv_event_cFUs

  mr r3, r31
  lwz r30, 0x18 (sp)
  lwz r31, 0x1C (sp)
  lwz r0, 0x24 (sp)
  mtlr r0
  addi sp, sp, 0x20
  blr

; Shared helper for the custom Triforce Chart item get functions below.
; Takes the 0-indexed chart index in r3.
; If the player has already paid Tingle, sets that chart's deciphered bit.
.org @NextFreeSpace
.global simplified_auto_decipher_owned_chart
simplified_auto_decipher_owned_chart:
  stwu sp, -0x10 (sp)
  mflr r0
  stw r0, 0x14 (sp)
  stw r31, 0xC (sp)
  mr r31, r3

  lis r3, 0x803C522C@ha
  addi r3, r3, 0x803C522C@l
  li r4, 0x6B40 ; Unused event bit we use for having paid for Simplified Triforce Chart Deciphering
  bl isEventBit__11dSv_event_cFUs
  cmpwi r3, 0
  beq simplified_auto_decipher_end ; The player hasn't paid Tingle yet

  lis r3, 0x803C4CCC@ha
  addi r3, r3, 0x803C4CCC@l
  mr r4, r31
  bl onTriforce__16dSv_player_map_cFi

simplified_auto_decipher_end:
  lwz r31, 0xC (sp)
  lwz r0, 0x14 (sp)
  mtlr r0
  addi sp, sp, 0x10
  blr

; Custom item get functions for the 8 Triforce Charts.
; Each one calls the vanilla item get function first and then auto-deciphers the chart if the
; player has already paid Tingle. The randomizer repoints the item get function table entries
; for the Triforce Chart item IDs (0xF7-0xFE) at these when the option is enabled.
; Note that calling the vanilla function first also means Triforce Chart 8's re-decipher works:
; vanilla item_func_collectmap08 clears chart 8's deciphered bit, and we re-set it right after.
.org @NextFreeSpace
.global triforce_chart_1_auto_decipher_item_func
triforce_chart_1_auto_decipher_item_func:
  stwu sp, -0x10 (sp)
  mflr r0
  stw r0, 0x14 (sp)
  bl item_func_collectmap01__Fv
  li r3, 0
  bl simplified_auto_decipher_owned_chart
  lwz r0, 0x14 (sp)
  mtlr r0
  addi sp, sp, 0x10
  blr

.org @NextFreeSpace
.global triforce_chart_2_auto_decipher_item_func
triforce_chart_2_auto_decipher_item_func:
  stwu sp, -0x10 (sp)
  mflr r0
  stw r0, 0x14 (sp)
  bl item_func_collectmap02__Fv
  li r3, 1
  bl simplified_auto_decipher_owned_chart
  lwz r0, 0x14 (sp)
  mtlr r0
  addi sp, sp, 0x10
  blr

.org @NextFreeSpace
.global triforce_chart_3_auto_decipher_item_func
triforce_chart_3_auto_decipher_item_func:
  stwu sp, -0x10 (sp)
  mflr r0
  stw r0, 0x14 (sp)
  bl item_func_collectmap03__Fv
  li r3, 2
  bl simplified_auto_decipher_owned_chart
  lwz r0, 0x14 (sp)
  mtlr r0
  addi sp, sp, 0x10
  blr

.org @NextFreeSpace
.global triforce_chart_4_auto_decipher_item_func
triforce_chart_4_auto_decipher_item_func:
  stwu sp, -0x10 (sp)
  mflr r0
  stw r0, 0x14 (sp)
  bl item_func_collectmap04__Fv
  li r3, 3
  bl simplified_auto_decipher_owned_chart
  lwz r0, 0x14 (sp)
  mtlr r0
  addi sp, sp, 0x10
  blr

.org @NextFreeSpace
.global triforce_chart_5_auto_decipher_item_func
triforce_chart_5_auto_decipher_item_func:
  stwu sp, -0x10 (sp)
  mflr r0
  stw r0, 0x14 (sp)
  bl item_func_collectmap05__Fv
  li r3, 4
  bl simplified_auto_decipher_owned_chart
  lwz r0, 0x14 (sp)
  mtlr r0
  addi sp, sp, 0x10
  blr

.org @NextFreeSpace
.global triforce_chart_6_auto_decipher_item_func
triforce_chart_6_auto_decipher_item_func:
  stwu sp, -0x10 (sp)
  mflr r0
  stw r0, 0x14 (sp)
  bl item_func_collectmap06__Fv
  li r3, 5
  bl simplified_auto_decipher_owned_chart
  lwz r0, 0x14 (sp)
  mtlr r0
  addi sp, sp, 0x10
  blr

.org @NextFreeSpace
.global triforce_chart_7_auto_decipher_item_func
triforce_chart_7_auto_decipher_item_func:
  stwu sp, -0x10 (sp)
  mflr r0
  stw r0, 0x14 (sp)
  bl item_func_collectmap07__Fv
  li r3, 6
  bl simplified_auto_decipher_owned_chart
  lwz r0, 0x14 (sp)
  mtlr r0
  addi sp, sp, 0x10
  blr

.org @NextFreeSpace
.global triforce_chart_8_auto_decipher_item_func
triforce_chart_8_auto_decipher_item_func:
  stwu sp, -0x10 (sp)
  mflr r0
  stw r0, 0x14 (sp)
  bl item_func_collectmap08__Fv
  li r3, 7
  bl simplified_auto_decipher_owned_chart
  lwz r0, 0x14 (sp)
  mtlr r0
  addi sp, sp, 0x10
  blr

.close

.open "files/rels/d_a_npc_tc.rel" ; Tingle
; In daNpc_Tc_c::cutPresentProc, replace the call to analysisCollectMap (which deciphers only
; the single lowest-numbered owned undeciphered chart) with a call to our custom function that
; deciphers all owned charts at once and marks the player as having paid.
.org 0x61B0
  bl simplified_decipher_all_owned_charts
.close
