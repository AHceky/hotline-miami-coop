// (enemy we simulate) hand it to player slot global.coop_gslot regardless of distance
// (we died and wait to be revived; debug F6)
if global.coop_gslot<0 exit
if !variable_local_exists("coop_uid") exit
if !variable_local_exists("coop_own") exit
if coop_own=0 exit
var a;
a=0
if variable_local_exists("alert") a=alert
external_call(global.__net_event4_to,global.coop_gslot,3,room,coop_uid,floor(max(0,x))*10000+floor(max(0,y)),a)
coop_own=0
