// scrCoopAddDead(uid,room): put an enemy on the dead list (once); 1 if it was not there yet
if ds_list_find_index(global.coop_dead,argument0)>=0 return 0
ds_list_add(global.coop_dead,argument0)
ds_list_add(global.coop_dead_room,argument1)
return 1
