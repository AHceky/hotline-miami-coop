// debug overlay (only with --debug)
draw_set_font(fntDate)
draw_set_halign(fa_left)
draw_set_color(c_yellow)
global.coop_no=0
global.coop_np=0
with objEnemy {if variable_local_exists("coop_own") {if coop_own=1 global.coop_no+=1 else global.coop_np+=1}}
draw_text(view_xview[0]+8,view_yview[0]+40,"own "+string(global.coop_no)+" puppet "+string(global.coop_np)+" together "+string(global.coop_together)+" here "+string(global.coop_ninroom)+" rt "+string(coop_rt)+" rxbullets "+string(global.coop_dbg_b)+" ebul "+string(instance_number(objEBullet)))
draw_text(view_xview[0]+8,view_yview[0]+24,"room "+string(room)+" enemies "+string(instance_number(objEnemy))+" ko "+string(instance_number(objKnockedOut))+" trk "+string(ds_list_size(global.coop_trk_id))+" van "+string(ds_list_size(global.coop_van_uid))+" dead "+string(ds_list_size(global.coop_dead))+" subway "+string(instance_number(objESubwayStatic))+" case "+string(instance_number(objBriefcase))+" guns "+string(instance_number(objWeaponThrow))+" skin "+string(global.coop_skin))
if instance_exists(objPlayer) draw_text(view_xview[0]+8,view_yview[0]+56,"skin "+string(global.coop_skin)+" ok "+string(global.coop_skin_ok[global.coop_skin])+" map "+string(ds_map_size(global.coop_skinmap))+" spr "+string(objPlayer.sprite_index)+" "+sprite_get_name(objPlayer.sprite_index)+" -> "+string(scrCoopSkin1(objPlayer.sprite_index)))
global.coop_dbgs="doors"
with objDoorV global.coop_dbgs+=" "+string(round(image_angle))
global.coop_dbgs+="  weapons "+string(instance_number(objWeapon))+"/"+string(instance_number(objWeaponThrow))+" shots "+string(instance_number(objCoopShot))+" dead "+string(instance_number(objPlayerDead))+"  enemies "+string(instance_number(objEnemy))+" spawned"
with objEnemy {if variable_local_exists("coop_uid") {if coop_uid>=8000000 global.coop_dbgs+=" "+string(coop_uid)}}
draw_set_color(c_black) draw_rectangle(view_xview[0]+4,view_yview[0]+86,view_xview[0]+620,view_yview[0]+104,0) draw_set_color(c_yellow) draw_text(view_xview[0]+8,view_yview[0]+88,global.coop_dbgs)
draw_set_color(c_white)
