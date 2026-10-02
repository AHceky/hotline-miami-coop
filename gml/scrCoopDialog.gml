// (objCoopNet) conversation boxes (objPhoneConversation) advance and close together: event 8
// (room, line or -1 = closed, number of lines). The number of lines tells two conversations apart.
var cv;
cv=-1
if instance_exists(objPhoneConversation) {
cv=instance_find(objPhoneConversation,0)
global.coop_k=0
with cv {if variable_local_exists("messages") and variable_local_exists("current") global.coop_k=1}
if global.coop_k=0 cv=-1
}
if cv!=-1 {
if cv=coop_cv and cv.current!=coop_cvcur external_call(global.__net_event,8,room,cv.current,cv.messages)
coop_cv=cv
coop_cvcur=cv.current
coop_cvmsg=cv.messages
coop_cvroom=room
} else {
if coop_cv!=-1 external_call(global.__net_event,8,coop_cvroom,-1,coop_cvmsg)
coop_cv=-1
}
