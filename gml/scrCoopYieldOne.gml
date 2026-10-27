// (enemy) another player (slot global.coop_ks) hit this enemy and simulates it now. If we took it
// ourselves a moment ago (both hit it at once: both claims cross), rank decides, so it is not left
// to nobody.
if !variable_local_exists("coop_uid") exit
if coop_uid!=global.coop_k exit
if variable_local_exists("coop_lock") {if coop_lock>0 and coop_own=1 and global.coop_prank[global.coop_ks]=1 exit}
coop_own=0
coop_orph=0
coop_lock=0
