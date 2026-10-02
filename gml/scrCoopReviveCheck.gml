// (objCoopNet step) the partner lies dead on our floor: stand on the body and press E to revive them
coop_canrevive=0
if !instance_exists(objPlayer) exit
if external_call(global.__net_age)<0 or external_call(global.__net_age)>3000 exit
if external_call(global.__net_get,0)!=2 or external_call(global.__net_get,1)!=room exit
if point_distance(objPlayer.x,objPlayer.y,external_call(global.__net_get,2),external_call(global.__net_get,3))>28 exit
coop_canrevive=1
if global.coop_focus=1 and keyboard_check_pressed(ord("E")) external_call(global.__net_event,13,room,0,0)
