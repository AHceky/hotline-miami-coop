// (enemy instance) give it a co-op identity if it has none yet
if variable_local_exists("coop_uid") exit
var i,n,best,bd,d;
best=-1
bd=48
n=ds_list_size(global.coop_van_uid)
for (i=0;i<n;i+=1) {
d=point_distance(x,y,ds_list_find_value(global.coop_van_x,i),ds_list_find_value(global.coop_van_y,i))
if d<bd {bd=d best=i}
}
if best>=0 {
coop_uid=ds_list_find_value(global.coop_van_uid,best)
coop_own=ds_list_find_value(global.coop_van_own,best)
scrCoopVanDelete(best)
if coop_own=0 and global.coop_together=1 {
// it was the partner's puppet and something here changed it (we hit it): it is ours now
coop_own=1
coop_lock=60
external_call(global.__net_event,5,room,coop_uid,0)
}
} else {coop_uid=id coop_own=1}
