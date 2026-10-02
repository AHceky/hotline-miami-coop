// scrCoopReadCfg(key): the value of key= in hmcoop.txt, "" if missing
var fn,f,line,v,k;
fn=working_directory+"\hmcoop.txt"
v=""
k=argument0+"="
if !file_exists(fn) return v
f=file_text_open_read(fn)
while !file_text_eof(f) {
line=file_text_read_string(f)
file_text_readln(f)
if string_copy(line,1,string_length(k))=k v=string_copy(line,string_length(k)+1,string_length(line))
}
file_text_close(f)
return v
