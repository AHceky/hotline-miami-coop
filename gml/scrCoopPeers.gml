// (objCoopNet step, right after net_poll) snapshot of every peer slot, read by the other scripts:
// connected, state (0 none, 1 alive, 2 dead), room, position, frames on the floor, in the car, rank
// (1 = we win tie-breaks against them), name; coop_pin = alive on our floor.
var s,a;
global.coop_nconn=0
global.coop_ninroom=0
global.coop_nnames=""
for (s=0;s<global.coop_npeers;s+=1) {
external_call(global.__net_sel,s)
a=external_call(global.__net_age)
global.coop_page[s]=a
global.coop_pok[s]=(a>=0 and a<3000)
global.coop_pst[s]=external_call(global.__net_get,0)
global.coop_proom[s]=external_call(global.__net_get,1)
global.coop_px[s]=external_call(global.__net_get,2)
global.coop_py[s]=external_call(global.__net_get,3)
global.coop_prt[s]=external_call(global.__net_get,16)
global.coop_pcar[s]=external_call(global.__net_get,17)
global.coop_prank[s]=external_call(global.__net_rank)
global.coop_pname[s]=external_call(global.__net_peer)
global.coop_pin[s]=0
if global.coop_pok[s] {
global.coop_nconn+=1
if global.coop_nnames!="" global.coop_nnames+=", "
global.coop_nnames+=global.coop_pname[s]
if global.coop_proom[s]=room and global.coop_pst[s]=1 and a<1500 {global.coop_pin[s]=1 global.coop_ninroom+=1}
}
}
