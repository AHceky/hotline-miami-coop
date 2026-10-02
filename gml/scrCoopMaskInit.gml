// scrCoopMaskInit(): zero the mask offset tables (maskaddx/maskaddy) of the calling instance.
// scrUpdateMaskPos only fills them for some sprites, frames up to 100 are covered.
var k;
k=0
repeat (100) {maskaddx[k]=0 maskaddy[k]=0 k+=1}
