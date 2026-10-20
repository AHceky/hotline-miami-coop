// scrCoopFamilyObj(object): true for the enemy-family objects (the ones scrCoopWithFamily visits:
// objEnemy and its children, the knocked-out / crawling kinds)
var o;
o=argument0
if !object_exists(o) return 0
if o=objKnockedOut or o=objECrawl or o=objSwatKnockedOut or o=objSubwayKnockedOut or o=objHoboKnockedOut return 1
if o=objEHideM16 or o=objESubwayStatic or o=objBodyguardCrawl return 1
repeat (8) {
if o=objEnemy return 1
if o<0 return 0
o=object_get_parent(o)
}
return 0
