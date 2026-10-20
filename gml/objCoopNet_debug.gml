// Test hotkeys, only in builds made with --debug.
global.coop_debug=1
// F8 kill nearest enemy, F9 kill every enemy, F10 take the first exit arrow, F11 jump to chapter 1.
// automated tests: coop_cmd.txt next to the exe holds one command (a debug key name, or E = revive
// whoever lies dead on this floor, R = restart from the checkpoint); it is read and deleted
global.coop_dbgcmd=""
if coop_t mod 5=0 {if file_exists(working_directory+"\coop_cmd.txt") {
global.coop_k=file_text_open_read(working_directory+"\coop_cmd.txt")
global.coop_dbgcmd=file_text_read_string(global.coop_k)
file_text_close(global.coop_k)
file_delete(working_directory+"\coop_cmd.txt")
}}
if global.coop_dbgcmd="E" {var s; for (s=0;s<global.coop_npeers;s+=1) {if global.coop_pok[s] and global.coop_pst[s]=2 and global.coop_proom[s]=room external_call(global.__net_event4_to,s,13,room,0,0,0)}}
if global.coop_dbgcmd="N" and instance_exists(objPlayer) and instance_exists(objEnemy) {global.dbg_t=instance_nearest(objPlayer.x,objPlayer.y,objEnemy) with objPlayer {x=global.dbg_t.x+24 y=global.dbg_t.y if !place_free(x,y) x-=48}}
if global.coop_dbgcmd="R" {if file_exists(working_directory+"\tempsave.sav") {scrResetSurfaces() game_load(working_directory+"\tempsave.sav")}}
if global.coop_focus=1 or global.coop_dbgcmd!="" {
var c;
if (keyboard_check_pressed(vk_f8) or global.coop_dbgcmd="F8") and instance_exists(objPlayer) and instance_exists(objEnemy) {
with instance_nearest(objPlayer.x,objPlayer.y,objEnemy) {c=scrCoopBody(x,y,0) c.sprite_index=sprEBackMachinegun instance_destroy()}
}
if (keyboard_check_pressed(vk_f9) or global.coop_dbgcmd="F9") {
with objEnemy {c=scrCoopBody(x,y,0) c.sprite_index=sprEBackMachinegun instance_destroy()}
with objKnockedOut {c=scrCoopBody(x,y,0) c.sprite_index=sprEBackMachinegun instance_destroy()}
with objESubwayStatic {c=scrCoopBody(x,y,0) c.sprite_index=sprEBackMachinegun instance_destroy()}
}
if (keyboard_check_pressed(vk_f10) or global.coop_dbgcmd="F10") and instance_exists(objTransitioner) and instance_exists(objPlayer) and instance_exists(objEffector) {
global.dbg_t=instance_find(objTransitioner,0)
with objPlayer {x=global.dbg_t.x y=global.dbg_t.y persistent=1 addx=global.dbg_t.addx*3 addy=global.dbg_t.addy*3}
objEffector.next=1
objEffector.fade=1
objEffector.nextroom=global.dbg_t.nextroom
}
if (keyboard_check_pressed(vk_f5) or global.coop_dbgcmd="F5") and instance_exists(objPlayer) and instance_exists(objEnemy) {
with instance_nearest(objPlayer.x,objPlayer.y,objEnemy) {c=instance_create(x,y,objKnockedOut) c.angle=direction instance_destroy()}
}
if (keyboard_check_pressed(vk_f4) or global.coop_dbgcmd="F4") and instance_exists(objPlayer) and instance_exists(objEnemy) {
with instance_nearest(objPlayer.x,objPlayer.y,objEnemy) {c=instance_create(x,y,objEBullet) c.direction=point_direction(x,y,objPlayer.x,objPlayer.y) c.speed=4 c.image_angle=c.direction}
}
if (keyboard_check_pressed(vk_f7) or global.coop_dbgcmd="F7") and instance_exists(objPlayer) and instance_exists(objKnockedOut) {global.dbg_t=instance_nearest(objPlayer.x,objPlayer.y,objKnockedOut) with objPlayer {x=global.dbg_t.x y=global.dbg_t.y}}
if (keyboard_check_pressed(vk_f3) or global.coop_dbgcmd="F3") and instance_exists(objPlayer) and instance_exists(objPlayerCarEnter) {global.done=1 global.dbg_t=instance_find(objPlayerCarEnter,0) with objPlayer {x=global.dbg_t.x y=global.dbg_t.y}}
if (keyboard_check_pressed(vk_f2) or global.coop_dbgcmd="F2") and !instance_exists(objPhoneConversation) {external_call(global.__net_event,97,0,0,0) scrCoopDebugTalk()}
if (keyboard_check_pressed(ord("B")) or global.coop_dbgcmd="B") and instance_exists(objPlayer) and instance_exists(objDoorV) {with instance_nearest(objPlayer.x,objPlayer.y,objDoorV) {swinger=1 swingspeed=8 sound_play(sndDoorOpen)}}
if (keyboard_check_pressed(ord("J")) or global.coop_dbgcmd="J") {external_call(global.__net_event,96,0,0,0) {if !variable_global_exists("combo") {scrInitScore() scrResetScore()}} global.done=1 room_goto(rmTrainstationEntrance)}
if (keyboard_check_pressed(ord("M")) or global.coop_dbgcmd="M") {external_call(global.__net_event,95,0,0,0) scrCoopDebugSpawn()}
if (keyboard_check_pressed(ord("K")) or global.coop_dbgcmd="K") and instance_exists(objPlayer) and instance_exists(objWeapon) {global.dbg_t=instance_nearest(objPlayer.x,objPlayer.y,objWeapon) with objPlayer {x=global.dbg_t.x y=global.dbg_t.y scrPlayerPickUp()}}
if (keyboard_check_pressed(ord("X")) or global.coop_dbgcmd="X") and instance_exists(objPlayer) {with objPlayer {global.coop_k=instance_create(x,y,objPlayerDead) global.coop_k.sprite_index=sprPBackBlunt global.coop_k.image_angle=dir instance_destroy()}}
if (keyboard_check_pressed(ord("G")) or global.coop_dbgcmd="G") and instance_exists(objPlayer) {with objPlayer {x=global.coop_px[0]+10 y=global.coop_py[0]}}
if (keyboard_check_pressed(vk_f6) or global.coop_dbgcmd="F6") {global.coop_gslot=-1 global.coop_k=0 repeat (global.coop_npeers) {if global.coop_pin[global.coop_k] global.coop_gslot=global.coop_k global.coop_k+=1} scrCoopWithFamily(scrCoopGiveOne)}
if (keyboard_check_pressed(vk_f12) or global.coop_dbgcmd="F12") {external_call(global.__net_event,98,0,0,0) {if !variable_global_exists("combo") {scrInitScore() scrResetScore()} room_goto(rmTrainstationDownstairs)}}
if (keyboard_check_pressed(vk_f11) or global.coop_dbgcmd="F11") {external_call(global.__net_event,99,0,0,0) {if !variable_global_exists("combo") {scrInitScore() scrResetScore()} room_goto(rmApartment1Entrance)}}
}
// state dump for automated tests: coop_dbg.txt next to the exe, twice a second
if coop_t mod 30=0 {
global.coop_dbgs="room "+string(room)+" player "+string(instance_exists(objPlayer))+" dead "+string(instance_number(objPlayerDead))+" enemies "+string(instance_number(objEnemy))+" weapons "+string(instance_number(objWeapon))+" flying "+string(instance_number(objWeaponThrow))+" shots "+string(instance_number(objCoopShot))+" np "+string(global.coop_npeers)+" ages "+string(global.coop_page[0])+","+string(global.coop_page[1])+","+string(global.coop_page[2])+" st "+string(global.coop_pst[0])+" players "+string(global.coop_nconn)+" here "+string(global.coop_ninroom)+" ["+global.coop_nnames+"]"+" skin "+string(global.coop_skin)+" name "+global.coop_name+" peer "+global.coop_peerstr
with objWeapon global.coop_dbgs+=" W"+string(image_index)+"@"+string(round(x))+","+string(round(y))
global.coop_ka=0 global.coop_kb=0
with objEnemy {if variable_local_exists("coop_own") {if coop_own=1 global.coop_ka+=1 else global.coop_kb+=1}}
with objKnockedOut {if variable_local_exists("coop_own") {if coop_own=1 global.coop_ka+=1 else global.coop_kb+=1}}
global.coop_dbgs+=" deadlist "+string(ds_list_size(global.coop_dead))+" own "+string(global.coop_ka)+" pup "+string(global.coop_kb)+" ko "+string(instance_number(objKnockedOut))+" corpses "+string(instance_number(objDeadBody))+" ebul "+string(global.coop_dbg_b)
if instance_exists(objPlayer) global.coop_dbgs+=" P@"+string(round(objPlayer.x))+","+string(round(objPlayer.y))+" "+sprite_get_name(objPlayer.sprite_index)
global.coop_k=file_text_open_write(working_directory+"\coop_dbg.txt")
file_text_write_string(global.coop_k,global.coop_dbgs)
file_text_close(global.coop_k)
}
