// (enemy) copy the partner's simulation of this enemy when the partner owns it
if !variable_local_exists("coop_uid") exit
if !variable_local_exists("coop_own") coop_own=1
var o,tx,ty,s;
o=external_call(global.__net_es_get,coop_uid,0)
if coop_own=1 {
if o=-100000 exit
if variable_local_exists("coop_lock") {if coop_lock>0 exit}
// both sides simulate it: whoever arrived on this floor later gives way, ties go by rank
if global.coop_myrt+30<global.coop_prt coop_own=0
else if global.coop_prt+30<global.coop_myrt exit
else if global.coop_rank=1 exit
else coop_own=0
}
if o=-100000 exit
if o!=object_index {
// the partner's copy was knocked down / got up: become the same kind of object
if object_exists(o) scrCoopMorph(o)
exit
}
tx=external_call(global.__net_es_get,coop_uid,1)
ty=external_call(global.__net_es_get,coop_uid,2)
if point_distance(x,y,tx,ty)>64 {x=tx y=ty} else {x+=(tx-x)*0.5 y+=(ty-y)*0.5}
speed=0
if path_index>=0 path_end()
direction=external_call(global.__net_es_get,coop_uid,3)
if variable_local_exists("angle") angle=direction else image_angle=direction
s=external_call(global.__net_es_get,coop_uid,4)
if sprite_exists(s) sprite_index=s
image_index=external_call(global.__net_es_get,coop_uid,5)
image_speed=0
if variable_local_exists("alert") alert=external_call(global.__net_es_get,coop_uid,6)
