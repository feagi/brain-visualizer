extends RefCounted
class_name SVONode
## Represents a single (non leaf) node 

var child_bitmask: int = 0 # 8-bit mask (which of 8 children exist)
var children: Array[SVONode] = [null, null, null, null, null, null, null, null]

# NOTE: Children order by index in the array and bitmask is the following:
#        6───7
#       /│  /│
#      2───3 │
#      │ 4─│─5
#      │/  │/
#      0───1
# Yes, this is different than how FEAGI orders coordinates, but we do it this way to make the bitwise math easier
