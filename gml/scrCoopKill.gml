// (enemy instance) dies because another player killed it: leave a corpse and whatever the game's own
// death code would drop (the metro briefcase; its gun only if global.coop_drop: a kill happening now,
// not the dead list applied again after R or on coming back to a floor), no score
var c;
c=instance_create(x,y,objDeadBody)
c.coop_seen=1
if object_index=objDogPatrol {
c.sprite_index=sprDogDeadShot
c.image_index=floor(random(sprite_get_number(sprDogDeadShot)))
} else {
c.sprite_index=choose(sprEBackMachinegun,sprEBackMachinegun,sprEFrontMachinegun)
c.image_index=floor(random(4))
}
c.image_angle=random(360)
c.direction=c.image_angle
c.speed=0

// the metro level can only be finished by picking up this briefcase
if object_index=objESubwayStatic {
if sprite_index=sprESubwayBriefcase {
c=instance_create(x,y,objBriefcase)
c.speed=1+random(1)
c.friction=0.1
}
}

// armed enemies drop their gun, as in objEnemy's death code
if global.coop_drop=1 and (object_get_parent(object_index)=objEnemy or object_index=objEnemy) {
if object_index!=objDogPatrol and sprite_index!=sprEWalkUnarmed and sprite_index!=sprEGiveUp and variable_local_exists("ammo") {
c=instance_create(x,y,objWeaponThrow)
c.image_index=scrCurrentWeaponExt(sprite_index)
c.direction=random(360)
c.speed=1+random(1)
c.ammo=ammo
}
}
instance_destroy()
