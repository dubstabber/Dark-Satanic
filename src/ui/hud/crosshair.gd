class_name Crosshair
extends Control
## Draws the crosshair texture (tinted by `color`) centred on this control,
## or falls back to a 3x3 white dot with a thin ring when no texture is set.

@export var texture: Texture2D = null:
	set(value):
		texture = value
		queue_redraw()
@export_range(2.0, 64.0, 1.0) var size_px: float = 12.0:
	set(value):
		size_px = value
		queue_redraw()
@export var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	if texture != null:
		var tex_size := texture.get_size()
		draw_texture_rect(texture, Rect2(center - tex_size * 0.5, tex_size), false, color)
		return
	draw_rect(Rect2(center - Vector2(1.5, 1.5), Vector2(3, 3)), color)
	draw_arc(center, size_px * 0.5, 0.0, TAU, 24, color, 1.0, false)
