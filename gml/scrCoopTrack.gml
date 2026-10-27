// Kill sync, run from objCoopNet's end step.
// Every enemy keeps one co-op identity (coop_uid = its room-placed instance id) through the
// game's transforms (enemy -> knocked out -> gets up as a new instance, bash/kick animations).
// An identity is declared dead when a corpse made for it appears (scrCoopBody / scrCoopCorpse); deaths
// go to the others.
var tk,i,n,d,c,s,ld,ap;
tk=external_call(global.__net_tick)
// game_load rewinds coop_tick (and coop_room: the checkpoint is saved as the floor starts, before this
// script has seen the new room)
ld=(tk-coop_tick>2)
ap=0
if room!=coop_room or ld {
ap=1
// new room, or game_load rewound every variable: start over without reporting anything
ds_list_clear(global.coop_trk_id)
ds_list_clear(global.coop_trk_uid)
ds_list_clear(global.coop_trk_x)
ds_list_clear(global.coop_trk_y)
ds_list_clear(global.coop_trk_own)
ds_list_clear(global.coop_van_uid)
ds_list_clear(global.coop_van_x)
ds_list_clear(global.coop_van_y)
ds_list_clear(global.coop_van_age)
ds_list_clear(global.coop_van_own)
if room!=coop_room {
coop_sent_trans=0
coop_rt=0
}
if !instance_exists(objEffector) or instance_exists(objEffectorHouse) {
// not in a level (menus, apartment, cutscenes): forget which enemies are dead
ds_list_clear(global.coop_dead)
ds_list_clear(global.coop_dead_room)
} else if ld {
// R (restart from the floor's checkpoint): with someone else on this floor the floor stays as they
// have it (the dead stay dead); alone, it starts over like in the normal game, and the others forget
// this floor's dead too, so it is the same for them when they come here
// (someone counts as here while their last news, up to 10 s old, puts them on this floor: a lag
// spike must not make both sides forget)
c=0
for (s=0;s<global.coop_npeers;s+=1) {if global.coop_page[s]>=0 and global.coop_page[s]<10000 and global.coop_proom[s]=room c=1}
if c=0 {
scrCoopForgetRoom(room)
external_call(global.__net_event,16,room,0,0)
} else {
// ask for the weapon list again: ours just went back to the checkpoint
external_call(global.__net_event,17,room,0,0)
for (s=0;s<global.coop_npeers;s+=1) coop_wpres[s]=0
}
}
coop_room=room
}
coop_tick=tk

// tracked instances that disappeared since last step
n=ds_list_size(global.coop_trk_id)
for (i=0;i<n;i+=1) {
if !instance_exists(ds_list_find_value(global.coop_trk_id,i)) {
ds_list_add(global.coop_van_uid,ds_list_find_value(global.coop_trk_uid,i))
ds_list_add(global.coop_van_x,ds_list_find_value(global.coop_trk_x,i))
ds_list_add(global.coop_van_y,ds_list_find_value(global.coop_trk_y,i))
ds_list_add(global.coop_van_age,0)
ds_list_add(global.coop_van_own,ds_list_find_value(global.coop_trk_own,i))
}
}

// new enemy-family instances adopt a vanished identity nearby, or take their own id
scrCoopWithFamily(scrCoopTag)
// a floor just started (or R): the enemies already dead in this co-op game die at once, before their
// AI runs again, and without dropping their guns a second time
if ap=1 scrCoopApplyDead()

// new corpses resolve vanished identities as dead
with objDeadBody scrCoopCorpse()
with objDeadBurning scrCoopCorpse()

// unresolved for ~10 s: give up on it
for (i=ds_list_size(global.coop_van_age)-1;i>=0;i-=1) {
d=ds_list_find_value(global.coop_van_age,i)+1
if d>600 scrCoopVanDelete(i) else ds_list_replace(global.coop_van_age,i,d)
}

ds_list_clear(global.coop_trk_id)
ds_list_clear(global.coop_trk_uid)
ds_list_clear(global.coop_trk_x)
ds_list_clear(global.coop_trk_y)
ds_list_clear(global.coop_trk_own)
scrCoopWithFamily(scrCoopTrackAdd)
