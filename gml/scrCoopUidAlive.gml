// scrCoopUidAlive(uid): true if some enemy-family instance still carries this co-op identity
global.coop_k=argument0
global.coop_alive=0
scrCoopWithFamily(scrCoopUidAliveOne)
return global.coop_alive
