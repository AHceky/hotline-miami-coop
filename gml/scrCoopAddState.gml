// (enemy) add to the outgoing enemy-state packet if we simulate it
if !variable_local_exists("coop_uid") exit
if variable_local_exists("coop_own") {if coop_own=0 exit}
var a,al;
if variable_local_exists("angle") a=angle else a=image_angle
al=0
if variable_local_exists("alert") al=alert
external_call(global.__net_es_add,coop_uid,object_index,x,y,a,sprite_index,image_index,al)
