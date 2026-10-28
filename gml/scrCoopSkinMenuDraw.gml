// (objCoopNet draw) title screen: the chosen character walking, the co-op settings and how to change them
var px,py,spr,leg,fr,m0,m1,m2,m3,m4,loc;
px=view_xview[0]+28
py=view_yview[0]+view_hview[0]-28
spr=scrCoopSkin(sprPWalkUnarmed,global.coop_skin)
leg=scrCoopSkin(sprLegs,global.coop_skin)
fr=coop_rt/6
draw_sprite_ext(leg,fr mod sprite_get_number(leg),px,py,1,1,90,c_white,1)
draw_sprite_ext(spr,fr mod sprite_get_number(spr),px,py,1,1,90,c_white,1)
if scrCoopSkinMasked(global.coop_skin) and variable_global_exists("maskindex") {
if global.maskindex>=0 draw_sprite_ext(sprMasks,global.maskindex,px,py,1,1,90,c_white,1)
}
loc=external_call(global.__net_local)
draw_set_font(fntDate)
draw_set_halign(fa_left)
m0="CHARACTER: "+string_upper(scrCoopSkinName(global.coop_skin))+"   (C - CHANGE)"
m1="NAME: "+string_upper(global.coop_name)+" (N)    PLAYERS: "+global.coop_peerstr+" (I)"
m2="YOUR RADMIN / LAN IP: "+loc
if global.coop_room="" m3="ROOM CODE: NONE (K)" else m3="ROOM CODE: "+string_upper(global.coop_room)+" (K)"
if external_call(global.__net_steam) m4="STEAM: "+string_upper(external_call(global.__net_steam_state))+"   (F - STEAM FRIENDS)"
else m4="STEAM: "+string_upper(external_call(global.__net_steam_state))
draw_set_color(c_black)
draw_text(px+25,py-7,m0)
draw_text(view_xview[0]+9,view_yview[0]+25,m1)
draw_text(view_xview[0]+9,view_yview[0]+41,m2)
draw_text(view_xview[0]+9,view_yview[0]+57,m3)
draw_text(view_xview[0]+9,view_yview[0]+73,m4)
draw_set_color(make_color_rgb(255,200,80))
draw_text(px+24,py-8,m0)
draw_text(view_xview[0]+8,view_yview[0]+24,m1)
draw_text(view_xview[0]+8,view_yview[0]+40,m2)
draw_text(view_xview[0]+8,view_yview[0]+56,m3)
draw_text(view_xview[0]+8,view_yview[0]+72,m4)
draw_set_color(c_white)
