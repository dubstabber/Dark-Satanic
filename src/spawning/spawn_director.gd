class_name SpawnDirector
extends Node
## Plays a WaveTable: fires each SpawnEvent at its time, staggers individuals
## through a SpawnQueue and loops the table endlessly once it is exhausted.
## Time is driven through advance(delta); nothing here uses the engine clock.

signal enemy_spawned(enemy: Node3D, event: SpawnEvent)

@export var wave_table: WaveTable
@export var enemy_container: Node3D
## Where spawned enemies drop their gems (injected as `spawn_root` on their
## GemDropComponents); when null gems land next to the enemy, i.e. in enemy_container.
@export var drop_root: Node
## Anything with `func info() -> ArenaInfo`; when null a default ArenaInfo is used.
@export var arena: Node
## Player; injected onto spawned enemies and used for target_position.
@export var target: Node3D
@export var rng_seed: int = 0
## Multiplies every event's count (ceil).
@export_range(0.1, 10.0, 0.05) var difficulty_scale: float = 1.0
## Advance on the engine clock instead of waiting for external advance() calls.
@export var autonomous: bool = false

var rng := RandomNumberGenerator.new()
## Individuals dropped because max_alive was reached (capped at scheduling or at spawn time).
var dropped: int = 0

var _elapsed: float = 0.0
var _events: Array[SpawnEvent] = []
var _cursor: int = 0
var _loop_k: int = 0
var _queue := SpawnQueue.new()
var _started: bool = false
var _extended_this_advance: bool = false


func _physics_process(delta: float) -> void:
	if autonomous and _started:
		advance(delta)


func elapsed() -> float:
	return _elapsed


## Resets the clock and reloads the table; must be called before advance().
func start() -> void:
	if rng_seed != 0:
		rng.seed = rng_seed
	_elapsed = 0.0
	_cursor = 0
	_loop_k = 0
	dropped = 0
	_queue.clear()
	_events = wave_table.expanded() if wave_table != null else []
	_warn_about_table()
	_started = true


func advance(delta: float) -> void:
	if not _started or delta <= 0.0:
		return
	_elapsed += delta
	_extended_this_advance = false
	while _next_due():
		_schedule(_events[_cursor], _events[_cursor].time)
		_cursor += 1
	for item in _queue.pop_due(_elapsed):
		_spawn_one(item["event"], item["position"])


## Spawns an event immediately (ignores time and stagger). Returns the spawned nodes.
func spawn_now(event: SpawnEvent) -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	if event == null:
		return nodes
	for position in _positions_for(event):
		var node := _spawn_one(event, position)
		if node != null:
			nodes.append(node)
	return nodes


## Enemies (nodes with a `died` signal) in the container that are not queued for deletion.
func alive_count() -> int:
	if enemy_container == null:
		return 0
	var alive := 0
	for child in enemy_container.get_children():
		if is_enemy(child):
			alive += 1
	return alive


## True for a live enemy node: anything exposing `died` that is not being freed.
static func is_enemy(node: Node) -> bool:
	return node is Node3D and node.has_signal("died") and not node.is_queued_for_deletion()


func max_alive() -> int:
	return wave_table.max_alive if wave_table != null else 0


func pending_count() -> int:
	return _queue.size()


func arena_info() -> ArenaInfo:
	var info: ArenaInfo = arena.info() if arena != null and arena.has_method("info") else ArenaInfo.new()
	if target != null and target.is_inside_tree():
		info.target_position = target.global_position
	return info


func _next_due() -> bool:
	if _cursor >= _events.size():
		_extend_loop()
	return _cursor < _events.size() and _events[_cursor].time <= _elapsed


## Appends the next endless loop block lazily: at most one block per advance() and only
## once the clock has reached it, so a runaway table can never stall a frame.
func _extend_loop() -> void:
	if wave_table == null or not wave_table.loops() or _events.is_empty() or _extended_this_advance:
		return
	if _elapsed < wave_table.loop_block_start(_loop_k + 1):
		return
	_loop_k += 1
	_extended_this_advance = true
	_events.append_array(wave_table.loop_events(_loop_k))


func _schedule(event: SpawnEvent, at_time: float) -> void:
	_queue.push(event, at_time, _positions_for(event))


## Positions for the event's (scaled) count, capped to the room left under max_alive.
func _positions_for(event: SpawnEvent) -> Array[Vector3]:
	var count := int(ceil(float(event.count) * difficulty_scale))
	if max_alive() > 0:
		var room := maxi(max_alive() - alive_count() - pending_count(), 0)
		if count > room:
			dropped += count - room
			count = room
	if count <= 0:
		return []
	var pattern: SpawnPattern = event.pattern
	if pattern == null:
		push_warning("SpawnDirector: event '%s' has no pattern, using a default ring" % event.label)
		pattern = RingPattern.new()
	return pattern.positions(count, arena_info(), rng)


func _spawn_one(event: SpawnEvent, position: Vector3) -> Node3D:
	if event.enemy_scene == null or enemy_container == null:
		return null
	if max_alive() > 0 and alive_count() >= max_alive():
		dropped += 1
		return null
	var node := event.enemy_scene.instantiate() as Node3D
	if node == null:
		return null
	if "target" in node:
		node.set("target", target)
	if "arena" in node:
		node.set("arena", arena)
	if "rng_seed" in node:
		node.set("rng_seed", rng.randi())
	node.position = enemy_container.to_local(position) if enemy_container.is_inside_tree() else position
	_wire_children(node)
	enemy_container.add_child(node)
	enemy_spawned.emit(node, event)
	return node


## Before the enemy enters the tree: nested spawners get the alive-cap veto and gem
## droppers get drop_root (duck-typed on the `spawn_root` property).
func _wire_children(node: Node) -> void:
	if node is SpawnerComponent:
		node.can_spawn = func() -> bool: return alive_count() < max_alive()
	if drop_root != null and node.has_method("drop") and "spawn_root" in node:
		node.set("spawn_root", drop_root)
	for child in node.get_children():
		_wire_children(child)


func _warn_about_table() -> void:
	if wave_table == null:
		return
	for problem in wave_table.validate():
		push_warning("SpawnDirector: %s: %s" % [wave_table.resource_path, problem])
