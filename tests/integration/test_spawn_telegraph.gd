extends GameTest
## The warning a directed spawn raises before it arrives: where the effect goes, when
## it appears, and the promise that adding it never moved the spawn itself.

const SpawnStub := preload("res://tests/fixtures/spawn_stub.tscn")
const RiftScene := preload("res://src/vfx/particles/spawn_rift.tscn")
const RiftCue := preload("res://assets/audio/cues/spawn_rift.tres")


class FakeArena:
	extends Node3D

	func info() -> ArenaInfo:
		return ArenaInfo.new(global_position, 20.0, 0.0)


var _world: Node3D
var _container: Node3D
var _vfx: Node3D
var _director: SpawnDirector


func before_each() -> void:
	super.before_each()
	_world = make_world()
	_container = Node3D.new()
	_container.name = "Enemies"
	_world.add_child(_container)
	_vfx = Node3D.new()
	_vfx.name = "Vfx"
	_world.add_child(_vfx)
	var arena := FakeArena.new()
	_world.add_child(arena)
	_director = SpawnDirector.new()
	_director.enemy_container = _container
	_director.vfx_root = _vfx
	_director.arena = arena
	_director.rng_seed = 11
	_director.telegraph_scene = RiftScene
	_director.telegraph_cue = RiftCue
	_director.telegraph_time = 0.85
	_director.wave_table = _table(2.0)
	_world.add_child(_director)
	watch_signals(_director)
	_director.start()


## One stub at a fixed point, `at` seconds into the run.
func _table(at: float, count: int = 1, stagger: float = 0.0) -> WaveTable:
	var pattern := PointPattern.new()
	pattern.point = Vector3(0, 1, 5)
	var event := SpawnEvent.new()
	event.time = at
	event.count = count
	event.stagger = stagger
	event.enemy_scene = SpawnStub
	event.pattern = pattern
	var table := WaveTable.new()
	table.events = [event]
	table.loop_from_time = -1.0
	return table


func _rifts() -> Array[Node]:
	var found: Array[Node] = []
	for child in _vfx.get_children():
		if child is OneShotVfx:
			found.append(child)
	return found


func test_the_warning_comes_up_a_telegraph_time_before_the_enemy() -> void:
	_director.advance(1.1)
	assert_eq(_rifts().size(), 0, "still too early")
	assert_eq(_director.alive_count(), 0)
	_director.advance(0.1)  # t = 1.2, one telegraph_time before 2.0
	assert_eq(_rifts().size(), 1, "warned")
	assert_signal_emitted(_director, "telegraphed")
	assert_eq(_director.alive_count(), 0, "the enemy is not here yet")
	_director.advance(0.7)  # t = 1.9
	assert_eq(_director.alive_count(), 0)
	_director.advance(0.1)  # t = 2.0
	assert_eq(_director.alive_count(), 1, "arrives exactly at the authored time")


func test_the_warning_stands_where_the_enemy_will_appear() -> void:
	_director.advance(2.0)
	var rift := _rifts()[0] as Node3D
	var enemy := _container.get_child(0) as Node3D
	assert_almost_eq(rift.global_position, Vector3(0, 1, 5), Vector3.ONE * 0.001)
	assert_almost_eq(rift.global_position, enemy.global_position, Vector3.ONE * 0.001)
	assert_eq(get_signal_parameters(_director, "telegraphed")[0], Vector3(0, 1, 5))


func test_the_warning_never_lands_in_the_enemy_container() -> void:
	_director.advance(2.0)
	for child in _container.get_children():
		assert_true(SpawnDirector.is_enemy(child), "%s is not an enemy" % child.name)
	assert_eq(_container.get_child_count(), 1)


func test_the_warning_is_not_counted_against_max_alive() -> void:
	_director.advance(1.3)
	assert_eq(_rifts().size(), 1)
	assert_eq(_director.alive_count(), 0, "a warning is not a living enemy")


func test_the_cue_plays_with_the_warning() -> void:
	_director.advance(2.0)
	assert_true(AudioManager.is_playing_cue(RiftCue))


func test_each_arrival_is_warned_exactly_once() -> void:
	_director.wave_table = _table(2.0, 3, 0.4)
	_director.start()
	_director.advance(3.0)
	assert_eq(_rifts().size(), 3, "one warning per individual, not per event")
	assert_signal_emit_count(_director, "telegraphed", 3)
	_director.advance(3.0)
	assert_signal_emit_count(_director, "telegraphed", 3, "and never re-warned")


func test_a_staggered_event_warns_each_individual_on_its_own_schedule() -> void:
	_director.wave_table = _table(2.0, 3, 0.5)
	_director.start()
	_director.advance(1.2)
	assert_eq(_rifts().size(), 1, "only the first of the stagger")
	_director.advance(0.5)
	assert_eq(_rifts().size(), 2)
	assert_eq(_director.alive_count(), 0, "none of them have arrived")


func test_without_a_scene_there_is_no_lead_and_the_schedule_is_untouched() -> void:
	_director.telegraph_scene = null
	_director.start()
	assert_eq(_director.telegraph_lead(), 0.0)
	_director.advance(1.99)
	assert_eq(_director.alive_count(), 0)
	assert_signal_not_emitted(_director, "telegraphed")
	_director.advance(0.01)
	assert_eq(_director.alive_count(), 1)
	assert_signal_emitted(_director, "telegraphed", "the moment is still announced for the cue")
	assert_eq(_rifts().size(), 0)


func test_a_zero_telegraph_time_disables_the_lead() -> void:
	_director.telegraph_time = 0.0
	_director.start()
	assert_eq(_director.telegraph_lead(), 0.0)
	_director.advance(1.99)
	assert_eq(_rifts().size(), 0)
	_director.advance(0.01)
	assert_eq(_rifts().size(), 1, "warning and arrival at once")
	assert_eq(_director.alive_count(), 1)


func test_spawn_now_skips_the_warning() -> void:
	var event := _table(0.0).events[0]
	assert_eq(_director.spawn_now(event).size(), 1)
	assert_eq(_rifts().size(), 0, "an immediate spawn has nothing to warn about")
	assert_signal_not_emitted(_director, "telegraphed")


func test_the_vfx_root_defaults_to_the_enemy_containers_parent() -> void:
	_director.vfx_root = null
	assert_same(_director.telegraph_root(), _world)
	_director.advance(2.0)
	assert_eq(_container.get_child_count(), 1, "still never inside the enemy container")


func test_telegraph_at_returns_null_when_there_is_nowhere_to_put_it() -> void:
	_director.vfx_root = null
	_director.enemy_container = null
	assert_null(_director.telegraph_root())
	assert_null(_director.telegraph_at(Vector3.ZERO))


func test_restarting_forgets_pending_warnings() -> void:
	_director.advance(1.3)
	assert_eq(_rifts().size(), 1)
	_director.start()
	_director.advance(1.1)
	assert_eq(_director.alive_count(), 0, "the schedule restarted from zero")


## The endless loop appends its next block lazily, so the block has to be appended early
## enough that its opening event still gets its full lead. milestone1.tres has an event
## sitting exactly on loop_from_time, which is the case that catches a missing term.
func test_the_first_arrival_of_every_endless_loop_block_is_warned_too() -> void:
	var pattern := PointPattern.new()
	pattern.point = Vector3(0, 1, 5)
	var opener := SpawnEvent.new()
	opener.time = 4.0
	opener.count = 1
	opener.enemy_scene = SpawnStub
	opener.pattern = pattern
	opener.label = "opener"
	var closer := SpawnEvent.new()
	closer.time = 8.0
	closer.count = 1
	closer.enemy_scene = SpawnStub
	closer.pattern = pattern
	closer.label = "closer"
	var table := WaveTable.new()
	table.events = [opener, closer]
	table.loop_from_time = 4.0
	table.min_loop_block = 8.0
	table.loop_count_multiplier = 1.0
	table.loop_interval_multiplier = 1.0
	_director.wave_table = table
	_director.start()

	var warned: Array[float] = []
	var arrived: Array[float] = []
	_director.telegraphed.connect(func(_p: Vector3) -> void: warned.append(_director.elapsed()))
	_director.enemy_spawned.connect(
		func(_n: Node3D, _e: SpawnEvent) -> void: arrived.append(_director.elapsed())
	)
	for i in 60 * 30:
		_director.advance(1.0 / 60.0)

	assert_gt(arrived.size(), 3, "the table looped")
	assert_eq(warned.size(), arrived.size(), "one warning per arrival")
	for i in arrived.size():
		var lead: float = arrived[i] - warned[i]
		assert_almost_eq(
			lead, _director.telegraph_lead(), 0.02,
			"arrival %d at t=%.2f got %.2f s of warning" % [i, arrived[i], lead]
		)


## Some arrivals are worth naming. A SpawnEvent carrying an `announce_cue` is warned with
## that sound instead of the generic rift, which is how a wave of skulls and the first
## cantor stop sounding like the same event.
func test_an_event_with_its_own_herald_is_announced_with_it() -> void:
	var herald: AudioCue = preload("res://assets/audio/cues/herald_choir.tres")
	_director.wave_table = _table(2.0)
	_director.wave_table.events[0].announce_cue = herald
	_director.start()
	AudioManager.reset()
	_director.advance(1.3)
	assert_eq(_rifts().size(), 1, "the sigil still goes up")
	assert_true(AudioManager.is_playing_cue(herald), "heralded")
	assert_false(AudioManager.is_playing_cue(RiftCue), "and not doubled with the generic rift")


func test_an_event_without_a_herald_falls_back_to_the_rift() -> void:
	AudioManager.reset()
	_director.advance(1.3)
	assert_true(AudioManager.is_playing_cue(RiftCue))


func test_telegraph_at_still_works_without_an_event() -> void:
	AudioManager.reset()
	assert_not_null(_director.telegraph_at(Vector3(1, 1, 1)), "the boss director calls it this way")
	assert_true(AudioManager.is_playing_cue(RiftCue))


func test_a_looped_block_keeps_its_herald() -> void:
	var herald: AudioCue = preload("res://assets/audio/cues/herald_swarm.tres")
	var event := SpawnEvent.new()
	event.announce_cue = herald
	event.label = "swarm"
	assert_same(event.retimed(90.0, 4).announce_cue, herald, "or the endless loop goes quiet")
