// (objCoopNet) title screen co-op menu:
//   C / Shift+C  character (only the ones built in), saved to hmcoop.txt, the partner sees it at once
//   I            the other players' Radmin / LAN IPs, comma separated (one is enough, the rest are learned)
//   N            your name above your ghost
//   K            room code: only players with the same code connect (empty = no code)
if !instance_exists(objTitle) exit
if global.coop_focus!=1 exit
var d,k,i,s;
if keyboard_check_pressed(ord("C")) {
d=1
if keyboard_check(vk_shift) d=-1
k=global.coop_skin
for (i=0;i<global.coop_nskins;i+=1) {
k=(k+d+global.coop_nskins) mod global.coop_nskins
if global.coop_skin_ok[k]=1 break
}
global.coop_skin=k
scrCoopSaveSkin(scrCoopSkinName(k))
}
if keyboard_check_pressed(ord("I")) {
io_clear()
s=get_string("Other players (Radmin IPs, comma separated; one is enough):",global.coop_peerstr)
if s!="" and s!=global.coop_peerstr {
if external_call(global.__net_set_peer,s) {global.coop_peerstr=s scrCoopSaveCfg("peer",s)} else show_message("Can't find address "+s)
}
io_clear()
}
if keyboard_check_pressed(ord("K")) {
io_clear()
s=get_string("Room code (the same for every player; empty = none):",global.coop_room)
if s!=global.coop_room {global.coop_room=s external_call(global.__net_set_room,s) scrCoopSaveCfg("room",s)}
io_clear()
}
if keyboard_check_pressed(ord("N")) {
io_clear()
s=string_copy(get_string("Your name (latin letters):",global.coop_name),1,15)
if s!="" {global.coop_name=s external_call(global.__net_set_name,s) scrCoopSaveCfg("name",s)}
io_clear()
}

