// scrCoopSkin(sprite, skin): the sprite to draw for a player wearing skin (0 Jacket, 1 Beard, 2 Richter, 3 Corey, 4 Jake, 5 Son, 6 Writer, 7 Pardo, 8 Henchman)
if argument1=0 return argument0
if !variable_global_exists("coop_skinmap") return argument0
var s;
s=ds_map_find_value(global.coop_skinmap,argument1*100000+argument0)
if s>0 return s
return argument0
