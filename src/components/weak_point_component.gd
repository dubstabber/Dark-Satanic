class_name WeakPointComponent
extends HurtboxComponent
## A hurtbox that only counts while `exposed`, with an optional critical multiplier.

signal weak_point_hit(hit: HitInfo)

@export var exposed: bool = true
@export_range(0.0, 10.0, 0.1) var crit_multiplier: float = 1.0


func receive_hit(hit: HitInfo) -> void:
	if exposed:
		weak_point_hit.emit(hit)
	super.receive_hit(hit)


func effective_multiplier(_hit: HitInfo) -> float:
	if not exposed:
		return 0.0
	return damage_multiplier * crit_multiplier
