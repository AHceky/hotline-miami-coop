// Remove every enemy whose identity is in the dead list (other players' kills, also after a checkpoint reload).
if ds_list_size(global.coop_dead)=0 exit
scrCoopWithFamily(scrCoopApplyDeadOne)
