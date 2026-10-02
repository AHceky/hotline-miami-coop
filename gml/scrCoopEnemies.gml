// (objCoopNet step) enemy simulation sync, 2-4 players.
// Every enemy is simulated by exactly one player (coop_own=1 there); the others show a puppet that
// copies the owner's position/sprite. Ownership follows whoever is closest to the enemy.
global.coop_together=(global.coop_ninroom>0)
if global.coop_ninroom=0 {
// nobody else alive on this floor (other floors, dead, disconnected): run every enemy ourselves again
coop_apart+=1
if coop_apart=30 scrCoopWithFamily(scrCoopTakeAll)
exit
}
coop_apart=0
global.coop_myrt=coop_rt
scrCoopWithFamily(scrCoopFollowState)
if coop_t mod 10=0 and instance_exists(objPlayer) {
global.coop_mx=objPlayer.x
global.coop_my=objPlayer.y
scrCoopWithFamily(scrCoopHandoff)
}
