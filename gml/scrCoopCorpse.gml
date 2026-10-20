// (corpse instance) a fresh corpse means an enemy died: the one it was made for (coop_src, set by
// scrCoopBody), or else the enemy that vanished nearest to it
if variable_local_exists("coop_seen") exit
coop_seen=1
var i,n,best,bd,d,uid;
best=-1
n=ds_list_size(global.coop_van_uid)
if variable_local_exists("coop_src") {
uid=coop_src
for (i=0;i<n;i+=1) {if ds_list_find_value(global.coop_van_uid,i)=uid best=i}
if best>=0 scrCoopVanDelete(best)
} else {
bd=56
for (i=0;i<n;i+=1) {
d=point_distance(xstart,ystart,ds_list_find_value(global.coop_van_x,i),ds_list_find_value(global.coop_van_y,i))
if d<bd {bd=d best=i}
}
if best<0 exit
uid=ds_list_find_value(global.coop_van_uid,best)
scrCoopVanDelete(best)
}
// a puppet that changed type keeps its identity alive: not a death
if scrCoopUidAlive(uid) exit
if scrCoopAddDead(uid,room) external_call(global.__net_event,1,room,uid,0)
