if !variable_local_exists("coop_uid") exit
ds_list_add(global.coop_trk_id,id)
ds_list_add(global.coop_trk_uid,coop_uid)
ds_list_add(global.coop_trk_x,x)
ds_list_add(global.coop_trk_y,y)
if variable_local_exists("coop_own") ds_list_add(global.coop_trk_own,coop_own) else ds_list_add(global.coop_trk_own,1)
