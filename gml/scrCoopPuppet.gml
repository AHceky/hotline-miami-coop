// (enemy) true while the partner simulates this enemy: its own AI must not run this step.
// The installer puts "if scrCoopPuppet() exit" at the top of every enemy step / alarm / animation-end code.
if !variable_local_exists("coop_own") return 0
if coop_own!=0 return 0
// a melee enemy the partner simulates still kills us on contact, like objEnemyMelee's own step
if instance_exists(objPlayer) and variable_local_exists("alert") {
if alert=1 and (object_index=objEnemyMelee or object_get_parent(object_index)=objEnemyMelee) {
if place_meeting(x+lengthdir_x(8,direction),y+lengthdir_y(8,direction),objPlayer) or place_meeting(x,y,objPlayer) {
global.my_id=id
scrPlayerDieMelee()
}
}
}
return 1
