// (knocked-out enemy) grabbed as a human shield. It never gets up again (a shield always ends as a
// corpse), so it counts as dead now: the others see it die where it lay instead of their copy getting
// up and fighting while we hold it.
if !variable_local_exists("coop_uid") exit
if scrCoopAddDead(coop_uid,room) external_call(global.__net_event,1,room,coop_uid,0)
