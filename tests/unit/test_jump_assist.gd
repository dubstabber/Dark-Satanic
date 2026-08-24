extends GameTest
## Coyote time and jump buffering, driven tick by tick the way MovementController does.

const DT := 1.0 / 60.0

var _stats: PlayerMovementStats
var _assist: JumpAssist


func before_each() -> void:
	super.before_each()
	_stats = PlayerMovementStats.new()
	_stats.coyote_time = 0.1
	_stats.jump_buffer_time = 0.15
	_stats.auto_bhop = false
	_assist = JumpAssist.new()


func _airborne(ticks: int, pressed: bool = false) -> void:
	for i in ticks:
		_assist.advance(false, pressed, _stats, DT)


func test_press_on_the_ground_jumps() -> void:
	_assist.advance(true, true, _stats, DT)
	assert_true(_assist.wants_jump(true, true, _stats))


func test_standing_still_does_not_jump() -> void:
	_assist.advance(true, false, _stats, DT)
	assert_false(_assist.wants_jump(true, false, _stats))


func test_held_jump_needs_auto_bhop() -> void:
	_assist.advance(true, false, _stats, DT)
	assert_false(_assist.wants_jump(true, true, _stats), "auto_bhop off: holding is not enough")
	_stats.auto_bhop = true
	assert_true(_assist.wants_jump(true, true, _stats))
	assert_false(_assist.wants_jump(true, false, _stats), "still needs the button down")


func test_standing_refills_the_coyote_grace() -> void:
	_assist.advance(true, false, _stats, DT)
	assert_almost_eq(_assist.coyote_remaining, _stats.coyote_time, 0.0001)


func test_jump_still_fires_just_after_walking_off_an_edge() -> void:
	_assist.advance(true, false, _stats, DT)
	_airborne(4)
	assert_gt(_assist.coyote_remaining, 0.0)
	_assist.advance(false, true, _stats, DT)
	assert_true(_assist.wants_jump(false, false, _stats), "coyote jump")


func test_jump_stops_firing_once_the_coyote_grace_runs_out() -> void:
	_assist.advance(true, false, _stats, DT)
	_airborne(10)
	assert_eq(_assist.coyote_remaining, 0.0)
	_assist.advance(false, true, _stats, DT)
	assert_false(_assist.wants_jump(false, true, _stats), "no jumping out of thin air")


func test_press_just_before_landing_fires_on_touchdown() -> void:
	_assist.advance(true, false, _stats, DT)
	_airborne(20)  # well past the coyote grace
	_assist.advance(false, true, _stats, DT)
	assert_false(_assist.wants_jump(false, false, _stats), "nothing happens while still falling")
	_airborne(5)
	assert_gt(_assist.buffer_remaining, 0.0)
	_assist.advance(true, false, _stats, DT)
	assert_true(_assist.wants_jump(true, false, _stats), "buffered press fires on landing")


func test_a_press_too_early_is_forgotten() -> void:
	_assist.advance(false, true, _stats, DT)
	_airborne(15)
	assert_eq(_assist.buffer_remaining, 0.0)
	_assist.advance(true, false, _stats, DT)
	assert_false(_assist.wants_jump(true, false, _stats))


func test_consume_stops_the_same_press_jumping_twice() -> void:
	_assist.advance(true, true, _stats, DT)
	assert_true(_assist.wants_jump(true, false, _stats))
	_assist.consume()
	assert_eq(_assist.coyote_remaining, 0.0)
	assert_eq(_assist.buffer_remaining, 0.0)
	assert_false(_assist.wants_jump(true, false, _stats))
	assert_false(_assist.wants_jump(false, false, _stats))


func test_zero_graces_still_jump_on_the_press_tick() -> void:
	_stats.coyote_time = 0.0
	_stats.jump_buffer_time = 0.0
	_assist.advance(true, true, _stats, DT)
	assert_true(_assist.wants_jump(true, false, _stats), "a designer zeroing the buffer must not break jumping")
	_assist.advance(true, false, _stats, DT)
	assert_false(_assist.wants_jump(true, false, _stats), "and nothing is remembered afterwards")


func test_reset_clears_both_graces() -> void:
	_assist.advance(true, true, _stats, DT)
	_assist.reset()
	assert_eq(_assist.coyote_remaining, 0.0)
	assert_eq(_assist.buffer_remaining, 0.0)
	assert_false(_assist.pressed_this_tick)


func test_missing_stats_are_inert_rather_than_fatal() -> void:
	var bare := JumpAssist.new()
	bare.advance(true, true, null, DT)
	assert_false(bare.wants_jump(true, true, null))
	assert_eq(bare.coyote_remaining, 0.0)
