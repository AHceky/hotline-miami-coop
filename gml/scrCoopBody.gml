// scrCoopBody(x,y,from other): the installer puts this in place of the game's own
// instance_create(x,y,objDeadBody) (argument2=0) and instance_create(other.x,other.y,objDeadBody) (1).
// The corpse remembers which co-op enemy died (coop_src): the instance running the death code if it is
// an enemy, or "other" for the second form (a door bash runs in the door, the enemy is other).
// A human shield's corpse was already counted when it was grabbed (scrCoopShieldTaken).
var c;
c=instance_create(argument0,argument1,objDeadBody)
global.coop_k=-1
if argument2=1 {with other {if variable_local_exists("coop_uid") global.coop_k=coop_uid}}
else if variable_local_exists("coop_uid") global.coop_k=coop_uid
if global.coop_k>=0 c.coop_src=global.coop_k
if object_index=objPlayerShieldMouse c.coop_seen=1
return c
