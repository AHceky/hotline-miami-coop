// (enemy) dies if its identity is in the dead list
if !variable_local_exists("coop_uid") exit
if ds_list_find_index(global.coop_dead,coop_uid)>=0 scrCoopKill()
