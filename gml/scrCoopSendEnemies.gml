// (objCoopNet end step) send the enemies we simulate, and copy our enemies' new bullets to the partner
// (unreliable: a bullet that arrives late is worse than one that does not arrive)
if global.coop_together=0 exit
with objEBullet {
if !variable_local_exists("coop_seen") {
coop_seen=1
external_call(global.__net_uevent4,4,room,floor(max(0,x))*10000+floor(max(0,y)),direction,speed)
}
}
if coop_t mod 2=1 exit
external_call(global.__net_es_begin)
scrCoopWithFamily(scrCoopAddState)
external_call(global.__net_es_send)
