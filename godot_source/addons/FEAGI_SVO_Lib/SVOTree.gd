extends RefCounted
class_name SVOTree
## A SVO implementation that is safely limited to arbritary non-cubic dimensions

const MAX_ALLOWED_SVO_DEPTH: int = 32 # You should never be approaching this ANYWAYS, 4b in any dimension!
const DEFAULT_PERCENTAGE_AREA_EXPECTED_TO_BE_ACTIVATED: float = 0.3 ## Percentage of the SVO expected to be activated. Responsible for initial memory allocation

# SVO data
var _root_node: SVONode
var _max_depth: int # can be 0 or greater (can be 0 since 2^0 = 1), where 0 is just the root node (1x1 cube)
var _user_dimension_limit: Vector3i # can be <1,1,1> or greater, represents the user limits of where nodes can go
var _tree_dimension_limit: int  # can be 1 or greater, represents the tree resolution limits of where nodes can go (this is essentially a vector but x y z are equal)
var _number_nodes_per_nonleaf_layer: PackedInt32Array = PackedInt32Array() # number of nodes per non-leaf layer, with the first element (the sole root) being 1. Will be _max_depth + 1 long
var _total_number_nonleaf_nodes: int = 1 # total number of nonleaf nodes. Starts at 1 due to root

# [Image] Data
var _image: Image # kept as reference to avoid constantly reallocating
var _image_data: PackedByteArray
var _image_size: Vector2i = Vector2i(1,1)
var _max_number_of_nonleaf_nodes_image_can_hold: int = 0


## Creates an SVO tree given a set of desired dimensions
static func create_SVOTree(target_minimum_dimensions: Vector3i) -> SVOTree:
	var max_dim_size: int = max(target_minimum_dimensions.x, target_minimum_dimensions.y, target_minimum_dimensions.z)
	if max_dim_size < 1:
		push_error("Dimensions must be or exceed <1,1,1> for SVO!")
		return null
	var calculated_depth: int = ceili(log(float(max_dim_size)) / log(2.0)) # since log is with base e, ln(a) / ln(2) = log_base_2(a)
	if calculated_depth > MAX_ALLOWED_SVO_DEPTH:
		push_error("Dimensions size Exceeded for SVO!")
		return null
	return SVOTree.new(calculated_depth, target_minimum_dimensions)

## Inits a SVO tree. Probably should not be used directly (use the above)
func _init(depth: int, representing_dimensions: Vector3i) -> void:
	# Set general vars
	_max_depth = depth
	_user_dimension_limit = representing_dimensions
	_tree_dimension_limit = 2 ** depth
	_image = Image.create_empty(1, 1, false,Image.FORMAT_RF)
	reset_tree()

## Gets the dimensions that this tree will accept values within
func get_user_dimensions() -> Vector3i:
	return _user_dimension_limit

## Returns the number of nodes in the tree, including the root node
func get_number_nonleaf_nodes() -> int:
	return _total_number_nonleaf_nodes

## Resets tree back to a single root node
func reset_tree() -> void:
	_root_node = SVONode.new()
	_number_nodes_per_nonleaf_layer = PackedInt32Array()
	_number_nodes_per_nonleaf_layer.resize(_max_depth)
	_number_nodes_per_nonleaf_layer[0] = 1 # root node
	_total_number_nonleaf_nodes = 1 # root node
	_recompute_texture_memory(ceili(float(_user_dimension_limit.x * _user_dimension_limit.y * _user_dimension_limit.z) * DEFAULT_PERCENTAGE_AREA_EXPECTED_TO_BE_ACTIVATED / 8.0))

## Adds a node to a given coordinate (or does nothing if node already exists)
func add_node(position: Vector3i) -> Error:
	if position.x >= _user_dimension_limit.x or position.y >= _user_dimension_limit.y or position.z >= _user_dimension_limit.z:
		push_error("Requested position is out of bounds! Not adding node!")
		return Error.ERR_PARAMETER_RANGE_ERROR
	if position.x < 0 or position.y < 0 or position.y < 0:
		push_error("Requested position is negative! Not adding node!")
		return Error.ERR_PARAMETER_RANGE_ERROR
	_add_node(position)
	return Error.OK

func export_as_shader_image() -> Image:
	# We have to calculate the byte structure: structure is the following (where each node is 4 bytes)
	# Node (inclusive byte ranges):
	#	Byte 0: Bitmask of active children (0-7),
	#	Byte 2-3: uint24 node count offset to first child node (if applicable), reverse byte order. If this node was a parent of a leaf (which is not exported, only represented by bitmask), then this value will be 0xFFFFFF
	# NOTE: leaf nodes are skipped in the output array, as we only need the bitmask of their parent node to ensure their existance (leaf nodes cannot have child nodes)
	# example structure, where the number represents the child index from the parent and the letter is a reference to the node
	# ( Root ) a
	#    ├── [0]b  
	#    │   └── [4]d ─ [0]g
	#    └── [7]cwdw_
	#        ├── [3]e ─ [3]h
	#        └── [7]f
	#             ├─── [1]i
	#             └─── [7]j
	# The above represents 8x8x8 cube with voxels (top down) <0,0,2>, <7,7,4>, <7,6,6>, <7,7,7>
	# Nodes are ordered by layer when outputted, skipping leaf nodes. So the output looking by node structure would be [a,b,c,d,e,f]
	# As bytes, this would look like the following (bytes, but each node seperated by parentheses, and sections by | for easier reading):
	# (0x81|0x010000)(0x10|0x020000)(0x88|0x020000)(0x01|0xFFFFFF)(0x08|0xFFFFFF)(0x82|0xFFFFFF)
	# or
	# (129|1,0,0)    (16|2,0,0)     (136|2,0,0)    (1|255|255|255)(8|255,255,255)(130|255,255,255)
	_export_as_shader_image()
	return _image


## While the memory allocation on the GPU can scale up automatically, this function must be called if you intend to scale down memory usage. Intensive so it shouldnt be called often
func shrink_memory_usage() -> void:
	_recompute_texture_memory(_total_number_nonleaf_nodes)

func get_tree_max_depth() -> int:
	return _max_depth


func _add_node(node_location: Vector3i) -> void:
	var current_node: SVONode = _root_node
	var size: int = _tree_dimension_limit
	var current_depth: int = 1 # skip root
	
	while size > 1:
		size /= 2
		var octant: int = (int(node_location.x >= size)) | (int(node_location.y >= size) << 1) | (int(node_location.z >= size) << 2) # bitmask octant
		
		if not (current_node.child_bitmask & (1 << octant)): # check if the bit at the "octant" index is false (no child mentioned)
			current_node.child_bitmask |= (1 << octant) # set the current node's bit at octant index to true as we are creating a child
			
			if not current_depth < _max_depth:
				# we have reached leaf node and labeled it, break out
				break
			
			# we are still in internal nodes (not at leaf level yet)
			_number_nodes_per_nonleaf_layer[current_depth] += 1
			_total_number_nonleaf_nodes += 1
			var new_node: SVONode = SVONode.new()
			current_node.children[octant] = new_node
			current_node = new_node
		else:
			# a child node exists in the correct location
			if not current_depth < _max_depth:
				# we have reached leaf node and it was already labeled, break out
				break
			current_node = current_node.children[octant]
		
		node_location %= size
		current_depth += 1

## Resizes the _image and the _image_data PackedByteArray as per node count
func _recompute_texture_memory(number_of_nodes_to_hold: int) -> void:
	# This is so when using the RF image format, where each pixel is 4 bytes (for 1 float normally), each node only takes 1 pixel
	var number_pixels_needed: int = number_of_nodes_to_hold
	
	# We need to (quickly) find the best rectangle that can hold this data.
	# This following algorithm likely isnt the most memory efficient but is fast
	var smallest_square_side: int = ceili(sqrt(float(number_pixels_needed)))
	var smallest_rect_side: int = ceili(float(number_pixels_needed) / float(smallest_square_side))
	_max_number_of_nonleaf_nodes_image_can_hold = smallest_square_side * smallest_rect_side
	
	# we calculated what we need to, now update this object
	_image_data = PackedByteArray()
	_image_data.resize(_max_number_of_nonleaf_nodes_image_can_hold * 4) # 4 bytes per pixel
	_image_size = Vector2i(smallest_square_side, smallest_rect_side)

## Exports [Image] by writing on the existing _image object
func _export_as_shader_image() -> void:
	if _total_number_nonleaf_nodes > _max_number_of_nonleaf_nodes_image_can_hold:
		_recompute_texture_memory(_total_number_nonleaf_nodes) # expand memory allocation if needed

	if _max_depth == 0:
		# unique case for single voxel area
		# TODO we should decide how to handle this. Perhaps have the child reference already be 0xFF?
		return
	
	if _total_number_nonleaf_nodes == 1:
		# Unique case where no nodes were added
		_image_data[0] = _root_node.child_bitmask
		_image_data[1] = 255
		_image_data[2] = 255
		_image_data[3] = 255
	
	else:
		# do all internal nodes
		var current_parent_nodes: Array[SVONode] = [_root_node]
		var current_node_array_index: int = 0
		for current_depth in range(_max_depth - 1): # loop for all nodes but leaf nodes
			var next_parent_nodes: Array[SVONode] = []
			var child_count_offset: int = 0
			var parent_node_index_of_current_depth = 0
			for current_parent_node in current_parent_nodes:
				var parent_nodes_remaining_at_this_depth: int = _number_nodes_per_nonleaf_layer[current_depth] - parent_node_index_of_current_depth
				
				var byte_index: int = current_node_array_index * 4
				_image_data[byte_index] = current_parent_node.child_bitmask # write bitmask for current parent node
				
				var child_node_offset_index: int = child_count_offset + parent_nodes_remaining_at_this_depth
				var child_offset_uint24: PackedByteArray = [0,0,0,0] # we will drop the 1st byte
				child_offset_uint24.encode_u32(0, child_node_offset_index)
				_image_data[byte_index + 1] = child_offset_uint24[0]
				_image_data[byte_index + 2] = child_offset_uint24[1]
				_image_data[byte_index + 3] = child_offset_uint24[2]
				# TODO check if endian order is correct?
				
				for child_index in range(8):
					if current_parent_node.child_bitmask & (1 << child_index): # loop over only children that are existing
						next_parent_nodes.append(current_parent_node.children[child_index])
						child_count_offset += 1
				
				parent_node_index_of_current_depth += 1
			
				current_node_array_index += 1
			current_parent_nodes = next_parent_nodes

		# do not export leaf nodes, instead just add the current parent nodes with the bitmasks, but set their address to #FFFFFF
		for current_parent_node in current_parent_nodes:
			var byte_index: int = current_node_array_index * 4
			_image_data[byte_index] = current_parent_node.child_bitmask
			_image_data[byte_index + 1] = 255
			_image_data[byte_index + 2] = 255
			_image_data[byte_index + 3] = 255
			current_node_array_index += 1
	
	# write to image
	_image.set_data(_image_size.x, _image_size.y, false, Image.FORMAT_RF, _image_data)
