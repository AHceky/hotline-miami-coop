// scrCoopCarReady(): called by objPlayerCarEnter once the player sits in the closed car.
// Returns 1 = drive off. The car waits until every connected player who is in a level sits in a car
// on this floor too (state field 17), or until Enter is pressed (drive alone).
global.coop_incar=3
if global.coop_cargo=1 return 1
var go,allin,any,s;
go=0
allin=1
any=0
for (s=0;s<global.coop_npeers;s+=1) {
if global.coop_pok[s] and global.coop_pst[s]!=0 {
any=1
if global.coop_pcar[s]!=1 or global.coop_proom[s]!=room allin=0
}
}
if any=0 or allin=1 go=1
else if global.coop_focus=1 and keyboard_check_pressed(vk_enter) go=1
if go=1 {
global.coop_cargo=1
global.coop_cargoroom=room
// players already waiting in their cars drive off with us
external_call(global.__net_event,6,room,0,0)
}
return go
