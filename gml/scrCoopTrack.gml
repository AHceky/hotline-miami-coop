// Kill sync, run from objCoopNet's end step.
// Every enemy keeps one co-op identity (coop_uid = its room-placed instance id) through the
// game's transforms (enemy -> knocked out -> gets up as a new instance, bash/kick animations).
// An identity is declared dead when a corpse appears where it vanished; deaths go to the partner.
var tk,i,n,d;
tk=external_call(global.__net_tick)
if room!=coop_room or tk-coop_tick>2 {
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
// left the level (menus, apartment, cutscenes): forget which enemies are dead
if !instance_exists(objEffector) or instance_exists(objEffectorHouse) ds_list_clear(global.coop_dead)
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
with objEnemy scrCoopTag()
with objKnockedOut scrCoopTag()
with objECrawl scrCoopTag()
with objSwatKnockedOut scrCoopTag()
with objSubwayKnockedOut scrCoopTag()
with objHoboKnockedOut scrCoopTag()
with objEHideM16 scrCoopTag()
with objESubwayStatic scrCoopTag()
with objBodyguardCrawl scrCoopTag()

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
with objEnemy scrCoopTrackAdd()
with objKnockedOut scrCoopTrackAdd()
with objECrawl scrCoopTrackAdd()
with objSwatKnockedOut scrCoopTrackAdd()
with objSubwayKnockedOut scrCoopTrackAdd()
with objHoboKnockedOut scrCoopTrackAdd()
with objEHideM16 scrCoopTrackAdd()
with objESubwayStatic scrCoopTrackAdd()
with objBodyguardCrawl scrCoopTrackAdd()
