// Hotline Miami co-op: load hmnet.dll once and make sure the net object exists.
// Safe to call any number of times (title screen, every player spawn, after game_load/game_restart).
if !variable_global_exists("coop_init") {
global.coop_init=1
global.coop_dll=working_directory+"\hmnet.dll"
global.__net_start=external_define(global.coop_dll,"net_start",dll_cdecl,ty_real,1,ty_string)
global.__net_set=external_define(global.coop_dll,"net_set",dll_cdecl,ty_real,2,ty_real,ty_real)
global.__net_send=external_define(global.coop_dll,"net_send",dll_cdecl,ty_real,0)
global.__net_poll=external_define(global.coop_dll,"net_poll",dll_cdecl,ty_real,0)
global.__net_get=external_define(global.coop_dll,"net_get",dll_cdecl,ty_real,1,ty_real)
global.__net_age=external_define(global.coop_dll,"net_age",dll_cdecl,ty_real,0)
global.__net_status=external_define(global.coop_dll,"net_status",dll_cdecl,ty_string,0)
global.__net_peer=external_define(global.coop_dll,"net_peer_name",dll_cdecl,ty_string,0)
global.__net_focused=external_define(global.coop_dll,"net_focused",dll_cdecl,ty_real,0)
global.__net_event=external_define(global.coop_dll,"net_event",dll_cdecl,ty_real,4,ty_real,ty_real,ty_real,ty_real)
global.__net_ev_count=external_define(global.coop_dll,"net_ev_count",dll_cdecl,ty_real,0)
global.__net_ev_get=external_define(global.coop_dll,"net_ev_get",dll_cdecl,ty_real,1,ty_real)
global.__net_ev_pop=external_define(global.coop_dll,"net_ev_pop",dll_cdecl,ty_real,0)
global.__net_tick=external_define(global.coop_dll,"net_tick",dll_cdecl,ty_real,0)
global.__net_skin_pref=external_define(global.coop_dll,"net_skin_pref",dll_cdecl,ty_real,0)
global.__net_beard_chance=external_define(global.coop_dll,"net_beard_chance",dll_cdecl,ty_real,0)
global.__net_event4=external_define(global.coop_dll,"net_event4",dll_cdecl,ty_real,5,ty_real,ty_real,ty_real,ty_real,ty_real)
global.__net_es_begin=external_define(global.coop_dll,"net_es_begin",dll_cdecl,ty_real,0)
global.__net_es_add=external_define(global.coop_dll,"net_es_add",dll_cdecl,ty_real,8,ty_real,ty_real,ty_real,ty_real,ty_real,ty_real,ty_real,ty_real)
global.__net_es_send=external_define(global.coop_dll,"net_es_send",dll_cdecl,ty_real,0)
global.__net_es_get=external_define(global.coop_dll,"net_es_get",dll_cdecl,ty_real,2,ty_real,ty_real)
global.__net_rank=external_define(global.coop_dll,"net_rank",dll_cdecl,ty_real,0)
global.__net_peers=external_define(global.coop_dll,"net_peers",dll_cdecl,ty_real,0)
global.__net_sel=external_define(global.coop_dll,"net_sel",dll_cdecl,ty_real,1,ty_real)
global.__net_event4_to=external_define(global.coop_dll,"net_event4_to",dll_cdecl,ty_real,6,ty_real,ty_real,ty_real,ty_real,ty_real,ty_real)
global.__net_local=external_define(global.coop_dll,"net_local",dll_cdecl,ty_string,0)
global.__net_set_peer=external_define(global.coop_dll,"net_set_peer",dll_cdecl,ty_real,1,ty_string)
global.__net_set_name=external_define(global.coop_dll,"net_set_name",dll_cdecl,ty_real,1,ty_string)
global.__net_version_mismatch=external_define(global.coop_dll,"net_version_mismatch",dll_cdecl,ty_real,0)
global.__net_uevent4=external_define(global.coop_dll,"net_uevent4",dll_cdecl,ty_real,5,ty_real,ty_real,ty_real,ty_real,ty_real)
global.__net_es_by=external_define(global.coop_dll,"net_es_by",dll_cdecl,ty_real,2,ty_real,ty_real)
global.__net_overflow=external_define(global.coop_dll,"net_overflow",dll_cdecl,ty_real,0)
global.__net_set_room=external_define(global.coop_dll,"net_set_room",dll_cdecl,ty_real,1,ty_string)
global.__net_steam=external_define(global.coop_dll,"net_steam",dll_cdecl,ty_real,0)
global.__net_steam_state=external_define(global.coop_dll,"net_steam_state",dll_cdecl,ty_string,0)
global.__net_steam_invite=external_define(global.coop_dll,"net_steam_invite",dll_cdecl,ty_real,0)
global.coop_ok=external_call(global.__net_start,working_directory+"\hmcoop.txt")

global.coop_trk_id=ds_list_create()
global.coop_trk_uid=ds_list_create()
global.coop_trk_x=ds_list_create()
global.coop_trk_y=ds_list_create()
global.coop_van_uid=ds_list_create()
global.coop_van_x=ds_list_create()
global.coop_van_y=ds_list_create()
global.coop_van_age=ds_list_create()
global.coop_dead=ds_list_create()
global.coop_dead_room=ds_list_create()
global.coop_trk_own=ds_list_create()
global.coop_van_own=ds_list_create()
// enemies another player took by hitting them (event 5), and when: a handoff of one of those that
// crossed it on the way is ignored, so two players never both simulate it
global.coop_claim_uid=ds_list_create()
global.coop_claim_t=ds_list_create()
global.coop_claim_s=ds_list_create()
global.coop_together=0
// other players: slots 0..np-1 (see scrCoopPeers)
global.coop_npeers=external_call(global.__net_peers)
global.coop_nconn=0
global.coop_ninroom=0
global.coop_nnames=""
global.coop_gslot=-1
var s;
for (s=0;s<global.coop_npeers;s+=1) {
global.coop_page[s]=-1 global.coop_pok[s]=0 global.coop_pst[s]=0 global.coop_proom[s]=-1 global.coop_px[s]=0
global.coop_py[s]=0 global.coop_prt[s]=0 global.coop_pcar[s]=0 global.coop_prank[s]=0 global.coop_pname[s]="" global.coop_pin[s]=0
}

// skins: scrCoopSkinInit is generated by the installer (empty map when HM2 is not installed)
scrCoopSkinInit()
var pref;
pref=external_call(global.__net_skin_pref)
// -1 = random: with beard_chance percent one of the available HM2 skins, otherwise Jacket
if pref<0 {
global.coop_skin=0
if random(100)<external_call(global.__net_beard_chance) {
var k,n;
n=0
for (k=1;k<global.coop_nskins;k+=1) {if global.coop_skin_ok[k]=1 n+=1}
if n>0 {
n=floor(random(n))
for (k=1;k<global.coop_nskins;k+=1) {if global.coop_skin_ok[k]=1 {if n=0 global.coop_skin=k n-=1}}
}
}
} else global.coop_skin=pref
if global.coop_skin<0 or global.coop_skin>=global.coop_nskins global.coop_skin=0
if global.coop_skin_ok[global.coop_skin]=0 global.coop_skin=0
global.coop_focus=1
global.coop_peerstr=scrCoopReadCfg("peer")
global.coop_name=scrCoopReadCfg("name")
global.coop_room=scrCoopReadCfg("room")
global.coop_incar=0
global.coop_cargo=0
global.coop_cargoroom=-1
global.coop_dbg_b=0
// 1 only while a kill another player just made is applied: the enemy drops its gun like in their game
global.coop_drop=0
}
if !instance_exists(objCoopNet) instance_create(0,0,objCoopNet)
