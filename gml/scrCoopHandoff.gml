// (enemy we simulate) hand it to the player on this floor who is clearly closer to it
if !variable_local_exists("coop_uid") exit
if !variable_local_exists("coop_own") exit
if coop_own=0 exit
if variable_local_exists("coop_lock") {if coop_lock>0 {coop_lock-=10 exit}}
var dm,dp,a,s,best,bd;
dm=point_distance(x,y,global.coop_mx,global.coop_my)
best=-1
bd=dm-64
for (s=0;s<global.coop_npeers;s+=1) {
if global.coop_pin[s] {
dp=point_distance(x,y,global.coop_px[s],global.coop_py[s])
if dp<bd {bd=dp best=s}
}
}
if best>=0 {
a=0
if variable_local_exists("alert") a=alert
external_call(global.__net_event4_to,best,3,room,coop_uid,floor(max(0,x))*10000+floor(max(0,y)),a)
coop_own=0
}
