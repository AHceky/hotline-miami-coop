// (objCoopShot step) fly until a wall or after 1.5 s
life-=1
if life<0 or place_meeting(x,y,objSolid) instance_destroy()
