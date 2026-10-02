// scrCoopCarReady(): called by objPlayerCarEnter once the player sits in the closed car.
// Returns 1 = drive off. With a connected partner the car waits until the partner sits in a car
// on the same floor too (state field 17), or until Enter is pressed (drive alone).
global.coop_incar=3
if global.coop_cargo=1 return 1
var age,go;
age=external_call(global.__net_age)
go=0
if age<0 or age>3000 go=1
else if external_call(global.__net_get,17)=1 and external_call(global.__net_get,1)=room go=1
else if global.coop_focus=1 and keyboard_check_pressed(vk_enter) go=1
if go=1 {
global.coop_cargo=1
global.coop_cargoroom=room
// a partner already waiting in their car drives off with us
external_call(global.__net_event,6,room,0,0)
}
return go
