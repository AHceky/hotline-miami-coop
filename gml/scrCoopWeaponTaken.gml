// (objWeapon being picked up by our player, from scrPlayerPickUp/2) the partner's copy of this weapon
// disappears too: event 9 (room, x*10000+y, weapon type)
external_call(global.__net_event4,9,room,floor(max(0,x))*10000+floor(max(0,y)),image_index,0)
