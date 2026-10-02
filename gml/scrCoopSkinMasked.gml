// scrCoopSkinMasked(skin): 1 if a player with this skin wears the HM1 mask on top (Richter and Corey
// have their own masks in their sprites)
if !variable_global_exists("coop_skinmap") return 1
if argument0<0 or argument0>=global.coop_nskins return 1
return global.coop_skin_mask[argument0]
