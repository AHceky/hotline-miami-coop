// Test hotkeys, only in builds made with --debug.
global.coop_debug=1
// F8 kill nearest enemy, F9 kill every enemy, F10 take the first exit arrow, F11 jump to chapter 1.
if global.coop_focus=1 {
var c;
if keyboard_check_pressed(vk_f8) and instance_exists(objPlayer) and instance_exists(objEnemy) {
with instance_nearest(objPlayer.x,objPlayer.y,objEnemy) {c=instance_create(x,y,objDeadBody) c.sprite_index=sprEBackMachinegun instance_destroy()}
}
if keyboard_check_pressed(vk_f9) {
with objEnemy {c=instance_create(x,y,objDeadBody) c.sprite_index=sprEBackMachinegun instance_destroy()}
with objKnockedOut {c=instance_create(x,y,objDeadBody) c.sprite_index=sprEBackMachinegun instance_destroy()}
with objESubwayStatic {c=instance_create(x,y,objDeadBody) c.sprite_index=sprEBackMachinegun instance_destroy()}
}
if keyboard_check_pressed(vk_f10) and instance_exists(objTransitioner) and instance_exists(objPlayer) and instance_exists(objEffector) {
global.dbg_t=instance_find(objTransitioner,0)
with objPlayer {x=global.dbg_t.x y=global.dbg_t.y persistent=1 addx=global.dbg_t.addx*3 addy=global.dbg_t.addy*3}
objEffector.next=1
objEffector.fade=1
objEffector.nextroom=global.dbg_t.nextroom
}
if keyboard_check_pressed(vk_f5) and instance_exists(objPlayer) and instance_exists(objEnemy) {
with instance_nearest(objPlayer.x,objPlayer.y,objEnemy) {c=instance_create(x,y,objKnockedOut) c.angle=direction instance_destroy()}
}
if keyboard_check_pressed(vk_f4) and instance_exists(objPlayer) and instance_exists(objEnemy) {
with instance_nearest(objPlayer.x,objPlayer.y,objEnemy) {c=instance_create(x,y,objEBullet) c.direction=point_direction(x,y,objPlayer.x,objPlayer.y) c.speed=4 c.image_angle=c.direction}
}
if keyboard_check_pressed(vk_f7) and instance_exists(objPlayer) and instance_exists(objKnockedOut) {global.dbg_t=instance_nearest(objPlayer.x,objPlayer.y,objKnockedOut) with objPlayer {x=global.dbg_t.x y=global.dbg_t.y}}
if keyboard_check_pressed(vk_f3) and instance_exists(objPlayer) and instance_exists(objPlayerCarEnter) {global.done=1 global.dbg_t=instance_find(objPlayerCarEnter,0) with objPlayer {x=global.dbg_t.x y=global.dbg_t.y}}
if keyboard_check_pressed(vk_f2) and !instance_exists(objPhoneConversation) {external_call(global.__net_event,97,0,0,0) scrCoopDebugTalk()}
if keyboard_check_pressed(ord("B")) and instance_exists(objPlayer) and instance_exists(objDoorV) {with instance_nearest(objPlayer.x,objPlayer.y,objDoorV) {swinger=1 swingspeed=8 sound_play(sndDoorOpen)}}
if keyboard_check_pressed(ord("J")) {external_call(global.__net_event,96,0,0,0) {if !variable_global_exists("combo") {scrInitScore() scrResetScore()}} global.done=1 room_goto(rmTrainstationEntrance)}
if keyboard_check_pressed(ord("M")) {external_call(global.__net_event,95,0,0,0) scrCoopDebugSpawn()}
if keyboard_check_pressed(ord("K")) and instance_exists(objPlayer) and instance_exists(objWeapon) {global.dbg_t=instance_nearest(objPlayer.x,objPlayer.y,objWeapon) with objPlayer {x=global.dbg_t.x y=global.dbg_t.y scrPlayerPickUp()}}
if keyboard_check_pressed(ord("X")) and instance_exists(objPlayer) and instance_exists(objEnemy) {global.my_id=instance_nearest(objPlayer.x,objPlayer.y,objEnemy) scrPlayerDieMelee()}
if keyboard_check_pressed(ord("G")) and instance_exists(objPlayer) {with objPlayer {x=external_call(global.__net_get,2)+10 y=external_call(global.__net_get,3)}}
if keyboard_check_pressed(vk_f6) scrCoopWithFamily(scrCoopGiveOne)
if keyboard_check_pressed(vk_f12) {external_call(global.__net_event,98,0,0,0) {if !variable_global_exists("combo") {scrInitScore() scrResetScore()} room_goto(rmTrainstationDownstairs)}}
if keyboard_check_pressed(vk_f11) {external_call(global.__net_event,99,0,0,0) {if !variable_global_exists("combo") {scrInitScore() scrResetScore()} room_goto(rmApartment1Entrance)}}
}
// state dump for automated tests: coop_dbg.txt next to the exe, twice a second
if coop_t mod 30=0 {
global.coop_dbgs="room "+string(room)+" player "+string(instance_exists(objPlayer))+" dead "+string(instance_number(objPlayerDead))+" enemies "+string(instance_number(objEnemy))+" weapons "+string(instance_number(objWeapon))+" flying "+string(instance_number(objWeaponThrow))+" shots "+string(instance_number(objCoopShot))+" partner "+string(external_call(global.__net_get,0))+" skin "+string(global.coop_skin)+" name "+global.coop_name+" peer "+global.coop_peerstr
with objWeapon global.coop_dbgs+=" W"+string(image_index)+"@"+string(round(x))+","+string(round(y))
if instance_exists(objPlayer) global.coop_dbgs+=" P@"+string(round(objPlayer.x))+","+string(round(objPlayer.y))+" "+sprite_get_name(objPlayer.sprite_index)
global.coop_k=file_text_open_write(working_directory+"\coop_dbg.txt")
file_text_write_string(global.coop_k,global.coop_dbgs)
file_text_close(global.coop_k)
}
