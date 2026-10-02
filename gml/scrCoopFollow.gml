// (objCoopNet) the partner left room argument0 for argument1 through an exit arrow: go with them
if room!=argument0 exit
if coop_sent_trans=1 exit
if !instance_exists(objEffector) or !instance_exists(objPlayer) exit
if objEffector.fade!=0 exit
global.coop_to=argument1
global.coop_tx=-100000
global.coop_ax=0
global.coop_ay=0
with objTransitioner {if variable_local_exists("nextroom") {if nextroom=global.coop_to and global.coop_tx=-100000 {global.coop_tx=x global.coop_ty=y if variable_local_exists("addx") {global.coop_ax=addx global.coop_ay=addy}}}}
with objTeleporter {if variable_local_exists("nextroom") {if nextroom=global.coop_to and global.coop_tx=-100000 {global.coop_tx=x global.coop_ty=y if variable_local_exists("addx") {global.coop_ax=addx global.coop_ay=addy}}}}
global.coop_el=-1
with objElevator {if variable_local_exists("nextroom") {if nextroom=global.coop_to and global.coop_tx=-100000 {
global.coop_tx=x global.coop_ty=y global.coop_el=id global.coop_emx=0 global.coop_emy=0
if variable_local_exists("movex") {global.coop_emx=movex global.coop_emy=movey}
}}}
if global.coop_tx=-100000 exit
with objPlayer {
x=global.coop_tx
y=global.coop_ty
addx=global.coop_ax*3
addy=global.coop_ay*3
persistent=1
}
if global.coop_el!=-1 {with objPlayer {movex=global.coop_emx movey=global.coop_emy if abs(movex)>0 or abs(movey)>0 move=1}}
objEffector.next=1
objEffector.fade=1
objEffector.nextroom=global.coop_to
coop_sent_trans=1
