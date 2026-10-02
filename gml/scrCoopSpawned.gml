// scrCoopSpawned(instance): (spawner: train door, SWAT spawn/van, dumpster) an enemy created at runtime
// gets an identity that is the same in both games - the room-placed spawner's id and how many it has
// spawned so far - so kills and enemy state of spawned enemies sync like those placed in the room.
// (Left to scrCoopTag it would get its own instance id, which differs between the two games, or adopt
// the identity of a nearby enemy that just vanished.)
if !variable_local_exists("coop_spawnk") coop_spawnk=0
coop_spawnk+=1
argument0.coop_uid=8000000+(id mod 100000)*64+coop_spawnk
argument0.coop_own=1
