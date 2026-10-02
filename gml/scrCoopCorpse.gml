// (corpse instance) a fresh corpse near a vanished enemy means that enemy died here
if variable_local_exists("coop_seen") exit
coop_seen=1
var i,n,best,bd,d,uid;
best=-1
bd=56
n=ds_list_size(global.coop_van_uid)
for (i=0;i<n;i+=1) {
d=point_distance(xstart,ystart,ds_list_find_value(global.coop_van_x,i),ds_list_find_value(global.coop_van_y,i))
if d<bd {bd=d best=i}
}
if best<0 exit
uid=ds_list_find_value(global.coop_van_uid,best)
scrCoopVanDelete(best)
// a puppet that changed type keeps its identity alive: not a death
if scrCoopUidAlive(uid) exit
if ds_list_find_index(global.coop_dead,uid)<0 {
ds_list_add(global.coop_dead,uid)
external_call(global.__net_event,1,room,uid,0)
}
