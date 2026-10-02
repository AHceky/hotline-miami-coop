// (enemy we simulate) debug: hand it to the partner regardless of distance
if !variable_local_exists("coop_uid") exit
if !variable_local_exists("coop_own") exit
if coop_own=0 exit
var a;
a=0
if variable_local_exists("alert") a=alert
external_call(global.__net_event4,3,room,coop_uid,floor(max(0,x))*10000+floor(max(0,y)),a)
coop_own=0
