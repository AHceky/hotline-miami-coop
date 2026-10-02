// Connection status (title screen, and for a few seconds after it changes) + the partner's ghost.
var age,st,tx,ty,spr,img,ang,xs,ys,ls,col,msg;
age=external_call(global.__net_age)

if statustimer>0 or instance_exists(objTitle) {
if age<0 {msg="CO-OP: waiting for partner... ("+external_call(global.__net_status)+")" col=make_color_rgb(255,200,80)}
else if age>3000 {msg="CO-OP: partner lost" col=make_color_rgb(255,90,90)}
else {msg="CO-OP: connected to "+external_call(global.__net_peer) col=make_color_rgb(120,255,160)}
draw_set_font(fntDate)
draw_set_halign(fa_left)
draw_set_color(c_black)
draw_text(view_xview[0]+9,view_yview[0]+9,msg)
draw_set_color(col)
draw_text(view_xview[0]+8,view_yview[0]+8,msg)
draw_set_color(c_white)
}

if instance_exists(objTitle) scrCoopSkinMenuDraw()
if external_call(global.__net_version_mismatch) {
draw_set_font(fntDate)
draw_set_halign(fa_center)
draw_set_color(c_black)
draw_text(view_xview[0]+view_wview[0]/2+1,view_yview[0]+29,string_upper(external_call(global.__net_status)))
draw_set_color(make_color_rgb(255,90,90))
draw_text(view_xview[0]+view_wview[0]/2,view_yview[0]+28,string_upper(external_call(global.__net_status)))
draw_set_halign(fa_left)
draw_set_color(c_white)
}
if age<0 or age>3000 exit
// level-end car: both players have to sit in it
msg=""
if global.coop_incar>0 and global.coop_cargo=0 msg="WAITING FOR "+external_call(global.__net_peer)+" IN THE CAR  (ENTER - DRIVE ALONE)"
else if global.coop_incar=0 and external_call(global.__net_get,17)=1 and external_call(global.__net_get,1)=room msg=external_call(global.__net_peer)+" IS WAITING IN THE CAR"
if !instance_exists(objPlayer) and instance_exists(objPlayerDead) and external_call(global.__net_get,0)=1 and external_call(global.__net_get,1)=room msg=external_call(global.__net_peer)+" CAN REVIVE YOU (STAND ON YOU + E)   R - RESTART"
if msg!="" {
draw_set_font(fntDate)
draw_set_halign(fa_center)
draw_set_color(c_black)
draw_text(view_xview[0]+view_wview[0]/2+1,view_yview[0]+view_hview[0]-39,msg)
draw_set_color(make_color_rgb(255,200,80))
draw_text(view_xview[0]+view_wview[0]/2,view_yview[0]+view_hview[0]-40,msg)
draw_set_halign(fa_left)
draw_set_color(c_white)
}
st=external_call(global.__net_get,0)
if st=0 exit
if external_call(global.__net_get,1)!=room {first=1 exit}
tx=external_call(global.__net_get,2)
ty=external_call(global.__net_get,3)
if first=1 or point_distance(gx,gy,tx,ty)>64 {gx=tx gy=ty first=0} else {gx+=(tx-gx)*0.6 gy+=(ty-gy)*0.6}
spr=external_call(global.__net_get,4)
img=external_call(global.__net_get,5)
ang=external_call(global.__net_get,6)
xs=external_call(global.__net_get,7)
ys=external_call(global.__net_get,8)
ls=external_call(global.__net_get,9)
// partner's skin
spr=scrCoopSkin(spr,external_call(global.__net_get,15))
if ls>=0 ls=scrCoopSkin(ls,external_call(global.__net_get,15))
col=make_color_rgb(190,225,255)
if st=2 col=make_color_rgb(170,170,210)
// same additive floor light the real player draws, otherwise the ghost stands in the dark
draw_set_blend_mode(bm_add)
draw_circle_color(gx,gy,48+random(6),make_color_hsv(0,0,30),c_black,0)
draw_set_blend_mode(bm_normal)
// alpha must stay 1: the game renders into a surface and partial alpha punches dark holes in it
if ls>=0 {
if sprite_exists(ls) {
draw_sprite_ext(ls,external_call(global.__net_get,10),gx+1,gy+1,xs,external_call(global.__net_get,12),external_call(global.__net_get,11),c_black,0.5)
draw_sprite_ext(ls,external_call(global.__net_get,10),gx,gy,xs,external_call(global.__net_get,12),external_call(global.__net_get,11),col,1)
}
}
if sprite_exists(spr) {
draw_sprite_ext(spr,img,gx+1,gy+1,xs,ys,ang,c_black,0.5)
draw_sprite_ext(spr,img,gx,gy,xs,ys,ang,col,1)
}
// partner's mask: same offsets the game uses for that sprite (scrUpdateMaskPos), drawn like scrDrawMask
if st=1 and external_call(global.__net_get,13)=1 and scrCoopSkinMasked(external_call(global.__net_get,15)) {
var osp,lf,fi,md,dd,mx,my,mi;
osp=external_call(global.__net_get,4)
if osp!=coop_mspr {coop_mspr=osp scrCoopMaskInit() if sprite_exists(osp) scrUpdateMaskPos(osp)}
lf=1
if ys<0 lf=-1
fi=floor(img)
if fi<0 fi=0
if fi>99 fi=99
md=point_direction(0,0,maskaddx[fi],maskaddy[fi]*lf)+ang
dd=point_distance(0,0,maskaddx[fi],maskaddy[fi]*lf)
mx=lengthdir_x(dd,md)
my=lengthdir_y(dd,md)
mi=external_call(global.__net_get,14)
draw_sprite_ext(sprMasks,mi,gx+mx+1,gy+my+1,xs,ys,ang,c_black,0.25)
draw_sprite_ext(sprMasks,mi,gx+mx,gy+my,xs,ys,ang,col,1)
}
draw_set_font(fntDate)
draw_set_halign(fa_center)
draw_set_color(c_black)
draw_text(gx+1,gy-27,external_call(global.__net_peer))
draw_set_color(col)
draw_text(gx,gy-28,external_call(global.__net_peer))
if coop_canrevive=1 {
draw_set_color(c_black)
draw_text(gx+1,gy-43,"E - REVIVE")
draw_set_color(make_color_rgb(120,255,160))
draw_text(gx,gy-44,"E - REVIVE")
}
draw_set_halign(fa_left)
draw_set_color(c_white)
