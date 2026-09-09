class_name GalaxyGraphGen
extends RefCounted
## Internal to sim/galaxy: places systems in a disc and connects them.
## Everything draws from the caller's RNG in a fixed order — reordering any
## draw is a generation change and must bump GalaxyData.GENERATION_VERSION.


## Poisson-like dart throwing: uniform candidates in the disc, rejected under
## min spacing. The spacing relaxes when the disc is too tight to fit
## system_count, so generation always terminates.
static func place_systems(rng: RandomNumberGenerator, params: GalaxyParams) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var min_dist: float = params.spacing_factor * params.radius / sqrt(float(params.system_count))
	var attempts: int = 0
	while points.size() < params.system_count:
		attempts += 1
		if attempts > 60:
			min_dist *= 0.9
			attempts = 0
		var r: float = params.radius * sqrt(rng.randf())
		var angle: float = rng.randf() * TAU
		var candidate: Vector2 = Vector2(cos(angle), sin(angle)) * r
		if _clear_of(points, candidate, min_dist):
			points.append(candidate)
			attempts = 0
	return points


## Relative neighborhood graph filtered from the Delaunay triangulation
## (RNG is a subgraph of Delaunay and a supergraph of the MST, so the result
## is connected and free of edge crossings), plus a few long edges for loops.
static func build_lanes(
	rng: RandomNumberGenerator, points: PackedVector2Array, params: GalaxyParams
) -> Array[WarpLane]:
	var lanes: Array[WarpLane] = _neighborhood_lanes(points)
	var extra: int = int(floor(float(lanes.size()) * params.long_edge_ratio))
	_add_long_edges(rng, points, lanes, extra, params.radius)
	lanes.sort_custom(func(x: WarpLane, y: WarpLane) -> bool:
		return x.a < y.a or (x.a == y.a and x.b < y.b))
	return lanes


static func home_system(points: PackedVector2Array) -> int:
	var centroid: Vector2 = Vector2.ZERO
	for p: Vector2 in points:
		centroid += p
	centroid /= float(points.size())
	var best: int = 0
	for i: int in points.size():
		if points[i].distance_to(centroid) < points[best].distance_to(centroid):
			best = i
	return best


## Jump depth from home per system; unreachable systems (impossible for an
## RNG graph, cheap to guard anyway) report -1 so the caller can assert.
static func jump_depths(count: int, lanes: Array[WarpLane], home_id: int) -> Array[int]:
	var adjacency: Array = []
	adjacency.resize(count)
	for i: int in count:
		adjacency[i] = []
	for lane: WarpLane in lanes:
		adjacency[lane.a].append(lane.b)
		adjacency[lane.b].append(lane.a)
	var depths: Array[int] = []
	depths.resize(count)
	depths.fill(-1)
	depths[home_id] = 0
	var frontier: Array[int] = [home_id]
	while not frontier.is_empty():
		var next_frontier: Array[int] = []
		for current: int in frontier:
			for neighbor: int in adjacency[current]:
				if depths[neighbor] == -1:
					depths[neighbor] = depths[current] + 1
					next_frontier.append(neighbor)
		frontier = next_frontier
	return depths


static func _clear_of(points: PackedVector2Array, candidate: Vector2, min_dist: float) -> bool:
	for p: Vector2 in points:
		if p.distance_to(candidate) < min_dist:
			return false
	return true


static func _neighborhood_lanes(points: PackedVector2Array) -> Array[WarpLane]:
	var lanes: Array[WarpLane] = []
	for edge: Vector2i in _delaunay_edges(points):
		var length: float = points[edge.x].distance_to(points[edge.y])
		if _is_neighborhood_edge(points, edge.x, edge.y, length):
			lanes.append(WarpLane.make(edge.x, edge.y, length))
	return lanes


static func _delaunay_edges(points: PackedVector2Array) -> Array[Vector2i]:
	var seen: Dictionary[Vector2i, bool] = {}
	var edges: Array[Vector2i] = []
	var triangles: PackedInt32Array = Geometry2D.triangulate_delaunay(points)
	for t: int in range(0, triangles.size(), 3):
		for pair: Vector2i in [
			Vector2i(triangles[t], triangles[t + 1]),
			Vector2i(triangles[t + 1], triangles[t + 2]),
			Vector2i(triangles[t + 2], triangles[t]),
		]:
			var edge: Vector2i = Vector2i(mini(pair.x, pair.y), maxi(pair.x, pair.y))
			if not seen.has(edge):
				seen[edge] = true
				edges.append(edge)
	return edges


## RNG condition: keep (a, b) unless some c is closer to both endpoints.
static func _is_neighborhood_edge(
	points: PackedVector2Array, a: int, b: int, length: float
) -> bool:
	for c: int in points.size():
		if c == a or c == b:
			continue
		if points[c].distance_to(points[a]) < length and points[c].distance_to(points[b]) < length:
			return false
	return true


static func _add_long_edges(
	rng: RandomNumberGenerator,
	points: PackedVector2Array,
	lanes: Array[WarpLane],
	extra: int,
	radius: float,
) -> void:
	var existing: Dictionary[Vector2i, bool] = {}
	for lane: WarpLane in lanes:
		existing[Vector2i(lane.a, lane.b)] = true
	var added: int = 0
	var attempts: int = 0
	while added < extra and attempts < extra * 50:
		attempts += 1
		var a: int = rng.randi_range(0, points.size() - 1)
		var b: int = rng.randi_range(0, points.size() - 1)
		var key: Vector2i = Vector2i(mini(a, b), maxi(a, b))
		if a == b or existing.has(key):
			continue
		var length: float = points[a].distance_to(points[b])
		# Long enough to be a shortcut, short enough to stay plausible.
		if length < radius * 0.25 or length > radius * 0.75:
			continue
		existing[key] = true
		lanes.append(WarpLane.make(a, b, length))
		added += 1
