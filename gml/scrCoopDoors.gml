// (objCoopNet) our player swung a door: the partner's copy of the same door (same room-editor id)
// swings too (event 7). Remote swings are applied with swinger=2 so they never knock anyone down
// on the receiving side and are not sent back.
with objDoorV {
if !variable_local_exists("coop_ls") coop_ls=0
if swinger=1 and abs(swingspeed)>abs(coop_ls)+1 external_call(global.__net_event,7,room,id,swingspeed)
coop_ls=swingspeed
}
