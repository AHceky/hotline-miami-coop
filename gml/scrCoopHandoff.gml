// (enemy we simulate) hand it to the partner when they are clearly closer to it
if !variable_local_exists("coop_uid") exit
if !variable_local_exists("coop_own") exit
if coop_own=0 exit
if variable_local_exists("coop_lock") {if coop_lock>0 {coop_lock-=10 exit}}
var dm,dp,a;
dm=point_distance(x,y,global.coop_mx,global.coop_my)
dp=point_distance(x,y,global.coop_px,global.coop_py)
if dp+64<dm {
a=0
if variable_local_exists("alert") a=alert
external_call(global.__net_event4,3,room,coop_uid,floor(max(0,x))*10000+floor(max(0,y)),a)
coop_own=0
}
