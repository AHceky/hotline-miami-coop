// (puppet enemy) replace self with an instance of object argument0, keeping the co-op identity
// (the game sets these right after creating knocked-out / crawling enemies; their draw needs them)
var n;
n=instance_create(x,y,argument0)
n.coop_uid=coop_uid
n.coop_own=0
n.coop_lock=0
n.direction=direction
n.angle=direction
n.image_angle=direction
n.speed=0
instance_destroy()
