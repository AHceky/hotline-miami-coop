// (objCoopNet) the partner revived us at our corpse (event 13): a fresh player, unarmed, same mask
if instance_exists(objPlayer) or !instance_exists(objPlayerDead) exit
if instance_exists(objEffector) {if objEffector.fade!=0 exit}
var d,p;
d=instance_find(objPlayerDead,0)
global.executionx=d.x
global.executiony=d.y
p=instance_create(d.x,d.y,objPlayerMouse)
p.dir=d.image_angle
p.sprite_index=sprPWalkUnarmed
p.maskon=global.maskon
p.maskindex=global.maskindex
with p {if !place_free(x,y) move_outside_solid(direction,16)}
with objMaskDrop instance_destroy()
with objPlayerDead instance_destroy()
