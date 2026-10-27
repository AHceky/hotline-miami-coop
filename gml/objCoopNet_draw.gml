// Connection status (title screen, and for a few seconds after it changes) + the other players' ghosts.
var st,tx,ty,spr,img,ang,xs,ys,ls,col,msg,s,pskin,by;

if statustimer>0 or instance_exists(objTitle) {
if global.coop_nconn>0 {msg="CO-OP: connected to "+global.coop_nnames col=make_color_rgb(120,255,160)}
else if coop_everconn=1 {msg="CO-OP: players lost" col=make_color_rgb(255,90,90)}
else {msg="CO-OP: waiting for players... ("+external_call(global.__net_status)+")" col=make_color_rgb(255,200,80)}
draw_set_font(fntDate)
draw_set_halign(fa_left)
draw_set_color(c_black)
draw_text(view_xview[0]+9,view_yview[0]+9,msg)
draw_set_color(col)
draw_text(view_xview[0]+8,view_yview[0]+8,msg)
draw_set_color(c_white)
}

if instance_exists(objTitle) scrCoopSkinMenuDraw()
if external_call(global.__net_version_mismatch) or (external_call(global.__net_overflow) and (statustimer>0 or instance_exists(objTitle))) {
// below the co-op settings on the title screen
by=28
if instance_exists(objTitle) by=76
draw_set_font(fntDate)
draw_set_halign(fa_center)
draw_set_color(c_black)
draw_text(view_xview[0]+view_wview[0]/2+1,view_yview[0]+by+1,string_upper(external_call(global.__net_status)))
draw_set_color(make_color_rgb(255,90,90))
draw_text(view_xview[0]+view_wview[0]/2,view_yview[0]+by,string_upper(external_call(global.__net_status)))
draw_set_halign(fa_left)
draw_set_color(c_white)
}
if global.coop_nconn=0 exit

// bottom line: level-end car / revive
msg=""
if global.coop_incar>0 and global.coop_cargo=0 msg="WAITING FOR THE OTHERS IN THE CAR  (ENTER - DRIVE ALONE)"
else if global.coop_incar=0 {
for (s=0;s<global.coop_npeers;s+=1) {
if global.coop_pok[s] and global.coop_pcar[s]=1 and global.coop_proom[s]=room msg=global.coop_pname[s]+" IS WAITING IN THE CAR"
}
}
if !instance_exists(objPlayer) and instance_exists(objPlayerDead) and global.coop_ninroom>0 msg="THE OTHERS CAN REVIVE YOU (STAND ON YOU + E)   R - RESTART"
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

// ghosts
for (s=0;s<global.coop_npeers;s+=1) {
if !global.coop_pok[s] continue
st=global.coop_pst[s]
if st=0 continue
if global.coop_proom[s]!=room {gfirst[s]=1 continue}
external_call(global.__net_sel,s)
tx=global.coop_px[s]
ty=global.coop_py[s]
if gfirst[s]=1 or point_distance(gx[s],gy[s],tx,ty)>64 {gx[s]=tx gy[s]=ty gfirst[s]=0} else {gx[s]+=(tx-gx[s])*0.6 gy[s]+=(ty-gy[s])*0.6}
spr=external_call(global.__net_get,4)
img=external_call(global.__net_get,5)
ang=external_call(global.__net_get,6)
xs=external_call(global.__net_get,7)
ys=external_call(global.__net_get,8)
ls=external_call(global.__net_get,9)
pskin=external_call(global.__net_get,15)
spr=scrCoopSkin(spr,pskin)
if ls>=0 ls=scrCoopSkin(ls,pskin)
col=make_color_rgb(190,225,255)
if st=2 col=make_color_rgb(170,170,210)
// same additive floor light the real player draws, otherwise the ghost stands in the dark
draw_set_blend_mode(bm_add)
draw_circle_color(gx[s],gy[s],48+random(6),make_color_hsv(0,0,30),c_black,0)
draw_set_blend_mode(bm_normal)
// alpha must stay 1: the game renders into a surface and partial alpha punches dark holes in it
if ls>=0 {
if sprite_exists(ls) {
draw_sprite_ext(ls,external_call(global.__net_get,10),gx[s]+1,gy[s]+1,xs,external_call(global.__net_get,12),external_call(global.__net_get,11),c_black,0.5)
draw_sprite_ext(ls,external_call(global.__net_get,10),gx[s],gy[s],xs,external_call(global.__net_get,12),external_call(global.__net_get,11),col,1)
}
}
if sprite_exists(spr) {
draw_sprite_ext(spr,img,gx[s]+1,gy[s]+1,xs,ys,ang,c_black,0.5)
draw_sprite_ext(spr,img,gx[s],gy[s],xs,ys,ang,col,1)
}
// their mask: same offsets the game uses for that sprite (scrUpdateMaskPos), drawn like scrDrawMask
if st=1 and external_call(global.__net_get,13)=1 and scrCoopSkinMasked(pskin) {
var osp,lf,fi,md,dd,mx,my,mi,k;
osp=external_call(global.__net_get,4)
// offsets kept per ghost (gmx/gmy), recomputed only when that ghost's sprite changes
if osp!=coop_gmspr[s] {
coop_gmspr[s]=osp
scrCoopMaskInit()
if sprite_exists(osp) scrUpdateMaskPos(osp)
for (k=0;k<100;k+=1) {gmx[s,k]=maskaddx[k] gmy[s,k]=maskaddy[k]}
}
lf=1
if ys<0 lf=-1
fi=floor(img)
if fi<0 fi=0
if fi>99 fi=99
md=point_direction(0,0,gmx[s,fi],gmy[s,fi]*lf)+ang
dd=point_distance(0,0,gmx[s,fi],gmy[s,fi]*lf)
mx=lengthdir_x(dd,md)
my=lengthdir_y(dd,md)
mi=external_call(global.__net_get,14)
draw_sprite_ext(sprMasks,mi,gx[s]+mx+1,gy[s]+my+1,xs,ys,ang,c_black,0.25)
draw_sprite_ext(sprMasks,mi,gx[s]+mx,gy[s]+my,xs,ys,ang,col,1)
}
draw_set_font(fntDate)
draw_set_halign(fa_center)
draw_set_color(c_black)
draw_text(gx[s]+1,gy[s]-27,global.coop_pname[s])
draw_set_color(col)
draw_text(gx[s],gy[s]-28,global.coop_pname[s])
if coop_canrevive=s+1 {
draw_set_color(c_black)
draw_text(gx[s]+1,gy[s]-43,"E - REVIVE")
draw_set_color(make_color_rgb(120,255,160))
draw_text(gx[s],gy[s]-44,"E - REVIVE")
}
draw_set_halign(fa_left)
draw_set_color(c_white)
}
