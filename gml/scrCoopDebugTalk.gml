// scrCoopDebugTalk(): (debug builds) open a three-line test conversation
var c;
c=instance_create(0,0,objPhoneConversation)
c.sprite=sprPhone
with objEffector sprite=sprPhone
c.line1[0]="CO-OP TEST LINE 1"
c.line2[0]="CLICK TO GO ON"
c.line1[1]="CO-OP TEST LINE 2"
c.line2[1]=""
c.line1[2]="CO-OP TEST LINE 3"
c.line2[2]="LAST ONE"
c.messages=2
