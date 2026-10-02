// (enemy) the partner handed this enemy to us: simulate it from where they had it
if !variable_local_exists("coop_uid") exit
if coop_uid!=global.coop_k exit
coop_own=1
coop_lock=60
x=global.coop_kx
y=global.coop_ky
if variable_local_exists("alert") alert=global.coop_ka
