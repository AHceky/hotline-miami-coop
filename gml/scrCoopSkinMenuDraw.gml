// (objCoopNet draw) title screen: the chosen character walking, the co-op settings and how to change them
var px,py,spr,leg,fr,m0,m1,m2,loc;
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
m1="NAME: "+string_upper(global.coop_name)+" (N)    PARTNER: "+global.coop_peerstr+" (I)"
m2="YOUR RADMIN / LAN IP: "+loc
draw_set_color(c_black)
draw_text(px+25,py-7,m0)
draw_text(view_xview[0]+9,view_yview[0]+25,m1)
draw_text(view_xview[0]+9,view_yview[0]+41,m2)
draw_set_color(make_color_rgb(255,200,80))
draw_text(px+24,py-8,m0)
draw_text(view_xview[0]+8,view_yview[0]+24,m1)
draw_text(view_xview[0]+8,view_yview[0]+40,m2)
draw_set_color(c_white)
