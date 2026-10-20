// Field layout (must match objCoopNet_draw):
// 0 state (0 none, 1 alive, 2 dead)  1 room  2 x  3 y  4 sprite  5 frame  6 angle
// 7 xscale  8 body yscale  9 leg sprite (-1 none)  10 leg frame  11 leg angle  12 yscale
// 13 maskon  14 maskindex  15 skin (0 Jacket, 1 Beard)  16 frames spent on this floor
// 17 sitting in the level-end car (waiting or driving off)
external_call(global.__net_poll)
scrCoopPeers()
if global.coop_nconn>0 coop_everconn=1

// reliable events from the partner: 1 = enemy killed (room, uid), 2 = left room (from, to)
var et,ea,eb,ec,ed,c;
while external_call(global.__net_ev_count)>0 {
et=external_call(global.__net_ev_get,0)
ea=external_call(global.__net_ev_get,1)
eb=external_call(global.__net_ev_get,2)
ec=external_call(global.__net_ev_get,3)
ed=external_call(global.__net_ev_get,4)
if et=1 {
scrCoopAddDead(eb,ea)
if ea=room scrCoopApplyDead()
}
// 16 = a player restarted that floor alone (R): its enemies are alive again
if et=16 scrCoopForgetRoom(ea)
if et=2 scrCoopFollow(ea,eb)
// 3 = the partner hands us an enemy (room, uid, x*10000+y, alert); ignored if a third player took it
// by hitting it a moment ago (event 5 overtook the handoff)
if et=3 and ea=room {
c=ds_list_find_index(global.coop_claim_uid,eb)
if c>=0 {if current_time-ds_list_find_value(global.coop_claim_t,c)>800 or external_call(global.__net_ev_get,5)=ds_list_find_value(global.coop_claim_s,c) c=-1}
if c<0 {
global.coop_k=eb
global.coop_kx=floor(ec/10000)
global.coop_ky=ec-global.coop_kx*10000
global.coop_ka=ed
scrCoopWithFamily(scrCoopTakeOne)
}
}
// 5 = the partner took over an enemy by hitting it (room, uid)
if et=5 and ea=room {
global.coop_k=eb
scrCoopWithFamily(scrCoopYieldOne)
c=ds_list_find_index(global.coop_claim_uid,eb)
if c>=0 {ds_list_delete(global.coop_claim_uid,c) ds_list_delete(global.coop_claim_t,c) ds_list_delete(global.coop_claim_s,c)}
ds_list_add(global.coop_claim_uid,eb)
ds_list_add(global.coop_claim_t,current_time)
ds_list_add(global.coop_claim_s,external_call(global.__net_ev_get,5))
if ds_list_size(global.coop_claim_uid)>32 {ds_list_delete(global.coop_claim_uid,0) ds_list_delete(global.coop_claim_t,0) ds_list_delete(global.coop_claim_s,0)}
}
// 4 = a bullet fired by an enemy the partner simulates (room, x*10000+y, direction, speed)
if et=4 and ea=room {
global.coop_kx=floor(eb/10000)
c=instance_create(global.coop_kx,eb-global.coop_kx*10000,objEBullet)
c.direction=ec
c.speed=ed
c.image_angle=ec
c.coop_seen=1
if variable_global_exists("coop_debug") global.coop_dbg_b+=1
}
// 7 = the partner swung a door (room, door id, swing speed)
if et=7 and ea=room {
global.coop_k=eb
global.coop_kx=ec
with objDoorV {if id=global.coop_k {if abs(swingspeed)<2 sound_play(sndDoorOpen) swingspeed=global.coop_kx swinger=2 coop_ls=swingspeed}}
}
// 8 = the partner's conversation box moved on (room, line or -1 = closed, number of lines)
if et=8 and ea=room and instance_exists(objPhoneConversation) {
global.coop_k=eb
global.coop_kx=ec
with objPhoneConversation {if variable_local_exists("messages") and variable_local_exists("current") {if messages=global.coop_kx {
if global.coop_k<0 {if variable_local_exists("sprite") {if sprite=sprPhone with objAnsweringMachine active=0} instance_destroy()}
else if global.coop_k>current {current=global.coop_k reload=10}
}}}
}
// 9 = the partner picked up a weapon (room, x*10000+y, type): ours there goes away
if et=9 and ea=room {
global.coop_kx=floor(eb/10000)
global.coop_ky=eb-global.coop_kx*10000
global.coop_k=ec
global.coop_best=-1
global.coop_bd=64
with objWeapon {if point_distance(x,y,global.coop_kx,global.coop_ky)<global.coop_bd {global.coop_bd=point_distance(x,y,global.coop_kx,global.coop_ky) global.coop_best=id}}
with objWeaponThrow {if image_index=global.coop_k {if point_distance(x,y,global.coop_kx,global.coop_ky)<global.coop_bd {global.coop_bd=point_distance(x,y,global.coop_kx,global.coop_ky) global.coop_best=id}}}
if global.coop_best!=-1 with global.coop_best instance_destroy()
}
// 15 = the senior partner's weapon on the floor (room, x*10000+y, type, ammo): ours there becomes the same
if et=15 and ea=room {
global.coop_kx=floor(eb/10000)
global.coop_ky=eb-global.coop_kx*10000
global.coop_best=-1
global.coop_bd=24
with objWeapon {if point_distance(x,y,global.coop_kx,global.coop_ky)<global.coop_bd {global.coop_bd=point_distance(x,y,global.coop_kx,global.coop_ky) global.coop_best=id}}
if global.coop_best!=-1 {global.coop_best.image_index=ec global.coop_best.ammo=ed}
}
// 10 = the partner threw / dropped a weapon (room, x*10000+y, dir*64+speed*2, type*1000+ammo)
if et=10 and ea=room {
global.coop_kx=floor(eb/10000)
c=instance_create(global.coop_kx,eb-global.coop_kx*10000,objWeaponThrow)
c.direction=floor(ec/64)
c.speed=(ec-floor(ec/64)*64)/2
c.image_index=floor(ed/1000)
c.ammo=ed-floor(ed/1000)*1000
c.coop_ghost=1
}
// 12 = a bullet the partner fired (room, x*10000+y, direction, speed): drawn only
if et=12 and ea=room {
global.coop_kx=floor(eb/10000)
c=instance_create(global.coop_kx,eb-global.coop_kx*10000,objCoopShot)
c.direction=ec
c.speed=ed
c.image_angle=ec
}
// 13 = the partner revived us (room)
if et=13 and ea=room scrCoopRevive()
// 14 = the partner beat this floor's boss (room): ours goes down too
if et=14 and ea=room and instance_exists(objPlayer) {
with objBoss {c=instance_create(x,y,objDeadBody) c.sprite_index=sprite_index c.image_index=image_index c.coop_seen=1 instance_destroy()}
}
// 6 = the partner drove off in their car (room): if we sit in ours, we go too
if et=6 and ea=room and global.coop_incar>0 {global.coop_cargo=1 global.coop_cargoroom=room}
if et=99 and variable_global_exists("coop_debug") {if !variable_global_exists("combo") {scrInitScore() scrResetScore()} room_goto(rmApartment1Entrance)}
if et=95 and variable_global_exists("coop_debug") scrCoopDebugSpawn()
if et=96 and variable_global_exists("coop_debug") {{if !variable_global_exists("combo") {scrInitScore() scrResetScore()}} global.done=1 room_goto(rmTrainstationEntrance)}
if et=97 and variable_global_exists("coop_debug") {if !instance_exists(objPhoneConversation) scrCoopDebugTalk()}
if et=98 and variable_global_exists("coop_debug") {if !variable_global_exists("combo") {scrInitScore() scrResetScore()} room_goto(rmTrainstationDownstairs)}
external_call(global.__net_ev_pop)
}
coop_t+=1
coop_rt+=1
scrCoopEnemies()
if coop_t mod 10=0 scrCoopApplyDead()
scrCoopDoors()
scrCoopDialog()
scrCoopSkinMenu()
scrCoopReviveCheck()
// weapons on the floor get random types in each game: when another player arrives on this floor, the
// player who has been here longest (ties: rank) sends their list and the others copy it (event 15).
// Arriving = connected and in this room, alive or not (a revive is not an arrival).
var s,arr;
arr=0
for (s=0;s<global.coop_npeers;s+=1) {
c=0
if global.coop_pok[s] and global.coop_proom[s]=room c=1
if coop_rt<5 coop_wpres[s]=0
if c=1 and coop_wpres[s]=0 arr=1
coop_wpres[s]=c
}
if arr=1 {
global.coop_k=1
for (s=0;s<global.coop_npeers;s+=1) {if coop_wpres[s]=1 {
if global.coop_prt[s]>coop_rt+30 global.coop_k=0
else if global.coop_prt[s]+30>=coop_rt and global.coop_prank[s]=0 global.coop_k=0
}}
if global.coop_k=1 with objWeapon external_call(global.__net_event4,15,room,floor(max(0,x))*10000+floor(max(0,y)),image_index,ammo)
}
// our bullets: the others on this floor see them fly (event 12, unreliable: a lost one is just not drawn)
with objBullet {if !variable_local_exists("coop_seen") {coop_seen=1 if global.coop_together=1 external_call(global.__net_uevent4,12,room,floor(max(0,x))*10000+floor(max(0,y)),direction,speed)}}
// dead and waiting to be revived: a player alive on this floor simulates our enemies meanwhile
if !instance_exists(objPlayer) and instance_exists(objPlayerDead) and global.coop_ninroom>0 and coop_t mod 20=0 {
global.coop_gslot=-1
for (s=0;s<global.coop_npeers;s+=1) {if global.coop_pin[s] global.coop_gslot=s}
scrCoopWithFamily(scrCoopGiveOne)
}
// beat the floor's boss: tell the partner (event 14)
if instance_exists(objBoss) coop_bossroom=room
if coop_bossroom=room and coop_bosssent!=room and variable_global_exists("done") {if global.done=1 and !instance_exists(objBoss) {
external_call(global.__net_event,14,room,0,0)
coop_bosssent=room
}}

// our own trip through an exit arrow: tell the partner so they come along
if coop_sent_trans=0 and instance_exists(objEffector) and instance_exists(objPlayer) {
if objEffector.next=1 and objEffector.fade=1 and objPlayer.persistent=1 {
external_call(global.__net_event,2,room,objEffector.nextroom,0)
coop_sent_trans=1
}
}

var p;
p=-1
if instance_exists(objPlayer) p=instance_find(objPlayer,0)
if p!=-1 {
with p {
external_call(global.__net_set,0,1)
external_call(global.__net_set,1,room)
external_call(global.__net_set,2,x)
external_call(global.__net_set,3,y)
external_call(global.__net_set,4,sprite_index)
external_call(global.__net_set,5,image_index)
external_call(global.__net_set,7,image_xscale)
external_call(global.__net_set,12,image_yscale)
if variable_local_exists("legsprite") and variable_local_exists("dir") {
external_call(global.__net_set,6,dir)
if variable_local_exists("left") external_call(global.__net_set,8,image_yscale*left) else external_call(global.__net_set,8,image_yscale)
external_call(global.__net_set,9,legsprite)
external_call(global.__net_set,10,legindex)
external_call(global.__net_set,11,legdir)
} else {
external_call(global.__net_set,6,image_angle)
external_call(global.__net_set,8,image_yscale)
external_call(global.__net_set,9,-1)
}
}
} else if instance_exists(objPlayerDead) {
with instance_find(objPlayerDead,0) {
external_call(global.__net_set,0,2)
external_call(global.__net_set,1,room)
external_call(global.__net_set,2,x)
external_call(global.__net_set,3,y)
external_call(global.__net_set,4,sprite_index)
external_call(global.__net_set,5,image_index)
external_call(global.__net_set,6,image_angle)
external_call(global.__net_set,7,image_xscale)
external_call(global.__net_set,8,image_yscale)
external_call(global.__net_set,9,-1)
}
} else {
external_call(global.__net_set,0,0)
external_call(global.__net_set,1,room)
}
external_call(global.__net_set,13,global.maskon)
external_call(global.__net_set,14,global.maskindex)
external_call(global.__net_set,15,global.coop_skin)
external_call(global.__net_set,16,coop_rt)
if global.coop_incar>0 global.coop_incar-=1
if global.coop_cargo=1 and room!=global.coop_cargoroom global.coop_cargo=0
external_call(global.__net_set,17,global.coop_incar>0 or global.coop_cargo=1)
external_call(global.__net_send)

// show the status line for 4 s whenever the link state changes
var cs;
cs=global.coop_nconn
if cs!=laststate {laststate=cs statustimer=240}
if statustimer>0 statustimer-=1
