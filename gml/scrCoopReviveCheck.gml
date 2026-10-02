// (objCoopNet step) a player lies dead on our floor: stand on the body and press E to revive them.
// coop_canrevive = their slot + 1 (0 = nobody to revive here)
coop_canrevive=0
if !instance_exists(objPlayer) exit
var s;
for (s=0;s<global.coop_npeers;s+=1) {
if global.coop_pok[s] and global.coop_pst[s]=2 and global.coop_proom[s]=room {
if point_distance(objPlayer.x,objPlayer.y,global.coop_px[s],global.coop_py[s])<=28 {
coop_canrevive=s+1
if global.coop_focus=1 and keyboard_check_pressed(ord("E")) external_call(global.__net_event4_to,s,13,room,0,0,0)
exit
}
}
}
