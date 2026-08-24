class_name JumpAssist
extends RefCounted
## The two bits of forgiveness around the jump edge that keep a chained bunny hop
## from being eaten by a single badly-timed frame:
##
## * **coyote time** — a jump still fires for a moment after walking off an edge;
## * **jump buffering** — a jump pressed just before touchdown fires on landing.
##
## Stateful but tree-free: the owner feeds it `advance()` once per tick, asks
## `wants_jump()` and calls `consume()` on the tick a jump actually starts.

var coyote_remaining: float = 0.0
var buffer_remaining: float = 0.0
## This tick's raw press edge, kept separately so a zero jump_buffer_time still
## jumps on the tick the button went down instead of disabling jumping entirely.
var pressed_this_tick: bool = false


## Feed this tick's floor state and jump edge before asking wants_jump().
func advance(on_floor: bool, jump_pressed: bool, stats: PlayerMovementStats, delta: float) -> void:
	if stats == null:
		return
	pressed_this_tick = jump_pressed
	coyote_remaining = stats.coyote_time if on_floor else maxf(coyote_remaining - delta, 0.0)
	buffer_remaining = stats.jump_buffer_time if jump_pressed else maxf(buffer_remaining - delta, 0.0)


## True when this tick should start a jump: standing (or inside coyote time) with a
## press now, a still-buffered press, or jump held down under auto bunny hop.
func wants_jump(on_floor: bool, jump_held: bool, stats: PlayerMovementStats) -> bool:
	if stats == null or (not on_floor and coyote_remaining <= 0.0):
		return false
	return pressed_this_tick or buffer_remaining > 0.0 or (jump_held and stats.auto_bhop)


## Called on the tick a jump starts, so no grace can fire a second one.
func consume() -> void:
	coyote_remaining = 0.0
	buffer_remaining = 0.0
	pressed_this_tick = false


## Forgets both graces (respawn, teleport, focus loss).
func reset() -> void:
	consume()
