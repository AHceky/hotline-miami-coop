// Remove every enemy whose identity is in the dead list (partner kills, also after a checkpoint reload).
if ds_list_size(global.coop_dead)=0 exit
with objEnemy {if variable_local_exists("coop_uid") {if ds_list_find_index(global.coop_dead,coop_uid)>=0 scrCoopKill()}}
with objKnockedOut {if variable_local_exists("coop_uid") {if ds_list_find_index(global.coop_dead,coop_uid)>=0 scrCoopKill()}}
with objECrawl {if variable_local_exists("coop_uid") {if ds_list_find_index(global.coop_dead,coop_uid)>=0 scrCoopKill()}}
with objSwatKnockedOut {if variable_local_exists("coop_uid") {if ds_list_find_index(global.coop_dead,coop_uid)>=0 scrCoopKill()}}
with objSubwayKnockedOut {if variable_local_exists("coop_uid") {if ds_list_find_index(global.coop_dead,coop_uid)>=0 scrCoopKill()}}
with objHoboKnockedOut {if variable_local_exists("coop_uid") {if ds_list_find_index(global.coop_dead,coop_uid)>=0 scrCoopKill()}}
with objEHideM16 {if variable_local_exists("coop_uid") {if ds_list_find_index(global.coop_dead,coop_uid)>=0 scrCoopKill()}}
with objESubwayStatic {if variable_local_exists("coop_uid") {if ds_list_find_index(global.coop_dead,coop_uid)>=0 scrCoopKill()}}
with objBodyguardCrawl {if variable_local_exists("coop_uid") {if ds_list_find_index(global.coop_dead,coop_uid)>=0 scrCoopKill()}}
