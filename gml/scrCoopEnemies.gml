// (objCoopNet step) enemy simulation sync.
// Every enemy is simulated by exactly one side (coop_own=1 there); the other side shows a puppet
// that copies the owner's position/sprite. Ownership follows whoever is closer to the enemy.
var st,tg;
st=external_call(global.__net_get,0)
tg=0
if external_call(global.__net_age)>=0 and external_call(global.__net_age)<1500 and st=1 {
if external_call(global.__net_get,1)=room tg=1
}
global.coop_together=tg
if tg=0 {
// partner gone (other floor, dead, disconnected): run every enemy ourselves again
coop_apart+=1
if coop_apart=30 scrCoopWithFamily(scrCoopTakeAll)
exit
}
coop_apart=0
global.coop_myrt=coop_rt
global.coop_prt=external_call(global.__net_get,16)
global.coop_rank=external_call(global.__net_rank)
scrCoopWithFamily(scrCoopFollowState)
if coop_t mod 10=0 and instance_exists(objPlayer) {
global.coop_px=external_call(global.__net_get,2)
global.coop_py=external_call(global.__net_get,3)
global.coop_mx=objPlayer.x
global.coop_my=objPlayer.y
scrCoopWithFamily(scrCoopHandoff)
}
