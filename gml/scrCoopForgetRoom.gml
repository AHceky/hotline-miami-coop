// scrCoopForgetRoom(room): drop that floor's enemies from the dead list (a player restarted it alone)
var i;
for (i=ds_list_size(global.coop_dead)-1;i>=0;i-=1) {
if ds_list_find_value(global.coop_dead_room,i)=argument0 {ds_list_delete(global.coop_dead,i) ds_list_delete(global.coop_dead_room,i)}
}
