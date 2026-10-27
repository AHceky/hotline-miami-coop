// (enemy we simulate) hand it to the player on this floor it should react to.
// Its AI only knows our objPlayer, so it must be simulated by the player it can see: a player in its
// sight (closer than 240, no wall between - the game's own check, scrSeePlayer, uses 220) beats one it
// cannot see; between two it sees, or two it cannot, the closer one. Handed over only when clearly
// better (64 px), so it does not flip back and forth.
if !variable_local_exists("coop_uid") exit
if !variable_local_exists("coop_own") exit
if coop_own=0 exit
if variable_local_exists("coop_lock") {if coop_lock>0 exit}
var dm,dp,a,s,best,bd;
dm=point_distance(x,y,global.coop_mx,global.coop_my)
if dm>240 dm+=1000 else if collision_line(x,y,global.coop_mx,global.coop_my,objSolid,0,1) dm+=1000
best=-1
bd=dm-64
for (s=0;s<global.coop_npeers;s+=1) {
if global.coop_pin[s] {
dp=point_distance(x,y,global.coop_px[s],global.coop_py[s])
if dp>240 dp+=1000 else if collision_line(x,y,global.coop_px[s],global.coop_py[s],objSolid,0,1) dp+=1000
if dp<bd {bd=dp best=s}
}
}
if best>=0 {
a=0
if variable_local_exists("alert") a=alert
external_call(global.__net_event4_to,best,3,room,coop_uid,floor(max(0,x))*10000+floor(max(0,y)),a)
coop_own=0
coop_orph=0
}
