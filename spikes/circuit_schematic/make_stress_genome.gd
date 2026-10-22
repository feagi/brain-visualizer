extends SceneTree
## Generates a synthetic brain (region tree, cortical areas, mappings) for Circuit Schematic stress tests.
## The output is a plain JSON description, not a FEAGI genome file.
## Run: godot --headless --path spikes/circuit_schematic -s res://make_stress_genome.gd -- --regions 60 --depth 5 --areas 600 --mappings 3000 --seed 1 --out /tmp/stress.json

const DEFAULTS: Dictionary = {"regions": 60, "depth": 5, "areas": 600, "mappings": 3000, "seed": 1}
const AREA_TYPES: Array[String] = ["IPU", "OPU", "MEMORY", "CUSTOM"]
const MAPPING_KINDS: Array[String] = ["excitatory", "inhibitory", "episodic"]


func _initialize() -> void:
	var params: Dictionary = parse_args(OS.get_cmdline_user_args())
	var data: Dictionary = generate(params)
	var out_path: String = String(params.get("out", "user://stress_genome.json"))
	var file: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s" % out_path)
		quit(1)
		return
	file.store_string(JSON.stringify(data))
	file.close()
	print("Wrote %d regions, %d areas, %d mappings to %s" % [data.regions.size(), data.areas.size(), data.mappings.size(), out_path])
	quit(0)


## Parses "--key value" pairs; integer values become ints.
static func parse_args(args: PackedStringArray) -> Dictionary:
	var params: Dictionary = DEFAULTS.duplicate()
	var i: int = 0
	while i < args.size():
		var arg: String = args[i]
		if arg.begins_with("--") and i + 1 < args.size():
			var value: String = args[i + 1]
			params[arg.substr(2)] = int(value) if value.is_valid_int() else value
			i += 2
		else:
			i += 1
	return params


## Builds the description. Region count excludes the root; depth counts levels below the root.
static func generate(params: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(params.seed)
	var region_count: int = int(params.regions)
	var max_depth: int = int(params.depth)

	var regions: Array = [{"id": "r0", "name": "root", "parent": "", "depth": 0}]
	# One chain guarantees the full depth exists; the rest attach to random shallower regions.
	for d in range(1, mini(max_depth, region_count) + 1):
		regions.append(_region(regions.size(), regions[regions.size() - 1].id, d))
	while regions.size() < region_count + 1:
		var parent: Dictionary = regions[rng.randi_range(0, regions.size() - 1)]
		if int(parent.depth) >= max_depth:
			continue
		regions.append(_region(regions.size(), parent.id, int(parent.depth) + 1))

	var areas: Array = []
	var areas_by_region: Dictionary = {}
	for i in int(params.areas):
		# The first two passes give every region at least one area; the rest land anywhere.
		var region: Dictionary = regions[i % regions.size()] if i < regions.size() * 2 else regions[rng.randi_range(0, regions.size() - 1)]
		var roll: float = rng.randf()
		var area_type: String = AREA_TYPES[0] if roll < 0.1 else (AREA_TYPES[1] if roll < 0.2 else (AREA_TYPES[2] if roll < 0.25 else AREA_TYPES[3]))
		var area: Dictionary = {"id": "a%d" % i, "name": "area_%d" % i, "region": region.id, "type": area_type}
		areas.append(area)
		if not areas_by_region.has(region.id):
			areas_by_region[region.id] = []
		areas_by_region[region.id].append(area.id)

	var region_by_id: Dictionary = {}
	for region in regions:
		region_by_id[region.id] = region
	var mappings: Array = []
	var seen: Dictionary = {}
	var target: int = int(params.mappings)
	var attempts: int = 0
	while mappings.size() < target and attempts < target * 50:
		attempts += 1
		var src: Dictionary = areas[rng.randi_range(0, areas.size() - 1)]
		var dst_id: String
		var roll: float = rng.randf()
		if roll < 0.6:
			dst_id = _random_from(rng, areas_by_region.get(src.region, []))
		elif roll < 0.85:
			var near_region: String = _neighbour_region(rng, region_by_id[src.region], regions)
			dst_id = _random_from(rng, areas_by_region.get(near_region, []))
		else:
			dst_id = areas[rng.randi_range(0, areas.size() - 1)].id
		if dst_id == "" or dst_id == src.id:
			continue
		var key: String = "%s>%s" % [src.id, dst_id]
		if seen.has(key):
			continue
		seen[key] = true
		var kind_roll: float = rng.randf()
		var kind: String = MAPPING_KINDS[0] if kind_roll < 0.8 else (MAPPING_KINDS[1] if kind_roll < 0.95 else MAPPING_KINDS[2])
		mappings.append({"src": src.id, "dst": dst_id, "kind": kind})

	return {"params": params, "regions": regions, "areas": areas, "mappings": mappings}


static func _region(index: int, parent_id: String, depth: int) -> Dictionary:
	return {"id": "r%d" % index, "name": "Region %d" % index, "parent": parent_id, "depth": depth}


static func _random_from(rng: RandomNumberGenerator, ids: Array) -> String:
	return "" if ids.is_empty() else String(ids[rng.randi_range(0, ids.size() - 1)])


## Parent, a child, or a sibling of the given region.
static func _neighbour_region(rng: RandomNumberGenerator, region: Dictionary, regions: Array) -> String:
	var candidates: Array = []
	if region.parent != "":
		candidates.append(region.parent)
	for other in regions:
		if other.parent == region.id or (other.parent == region.parent and other.id != region.id):
			candidates.append(other.id)
	return region.id if candidates.is_empty() else String(candidates[rng.randi_range(0, candidates.size() - 1)])
