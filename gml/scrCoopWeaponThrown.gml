// scrCoopWeaponThrown(objWeaponThrow): our player threw or dropped a weapon - the partner gets a copy that
// flies the same way (marked coop_ghost: it knocks nobody out there) and lands as a normal weapon.
// event 10 (room, x*10000+y, direction*64+speed*2, type*1000+ammo)
var w;
w=argument0
external_call(global.__net_event4,10,room,floor(max(0,w.x))*10000+floor(max(0,w.y)),floor(w.direction)*64+min(63,round(w.speed*2)),w.image_index*1000+max(0,w.ammo))
