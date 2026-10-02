// scrCoopSaveCfg(key, value): rewrite the key= line of hmcoop.txt, the other settings stay as they are
var fn,f,n,i,line,found,k;
fn=working_directory+"\hmcoop.txt"
k=argument0+"="
n=0
found=0
if file_exists(fn) {
f=file_text_open_read(fn)
while !file_text_eof(f) {
line=file_text_read_string(f)
file_text_readln(f)
if string_copy(line,1,string_length(k))=k {line=k+argument1 found=1}
if line!="" {global.coop_cfg[n]=line n+=1}
}
file_text_close(f)
}
if found=0 {global.coop_cfg[n]=k+argument1 n+=1}
f=file_text_open_write(fn)
for (i=0;i<n;i+=1) {file_text_write_string(f,global.coop_cfg[i]) file_text_writeln(f)}
file_text_close(f)
