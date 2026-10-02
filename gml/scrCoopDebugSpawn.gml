// scrCoopDebugSpawn(): (debug builds) spawn an enemy the way the train doors do, from the first door
// of the room (room-placed, so the same spawner on both sides)
if !instance_exists(objDoorV) exit
with instance_find(objDoorV,0) {
my_id=instance_create(x+24,y+24,objEnemyMelee) scrCoopSpawned(my_id)
}
