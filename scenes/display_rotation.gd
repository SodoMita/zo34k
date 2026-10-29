extends RefCounted
## Shared quarter-turn canvas geometry. Layout and input use the same transform;
## neither a physical window resize nor a rotated page may introduce letterboxes.


static func normalize(degrees: int) -> int:
	var angle := posmod(degrees, 360)
	return angle if angle in [0, 90, 180, 270] else 0


static func logical_size(window_size: Vector2, degrees: int) -> Vector2:
	var angle := normalize(degrees)
	return Vector2(window_size.y, window_size.x) if angle == 90 or angle == 270 else window_size


static func canvas_transform(window_size: Vector2, degrees: int) -> Transform2D:
	var logical := logical_size(window_size, degrees)
	var result := Transform2D(deg_to_rad(float(normalize(degrees))), Vector2.ZERO)
	result.origin = window_size * 0.5 - result.basis_xform(logical * 0.5)
	return result


## Controls must have equal opposite anchors BEFORE size is assigned. Keeping
## full-rect anchors here lets Godot overwrite the rotated size on the next frame.
static func apply_control(control: Control, window_size: Vector2, degrees: int, ui_scale: float = 1.0) -> void:
	if window_size.x < 1.0 or window_size.y < 1.0:
		return
	var factor := clampf(ui_scale, 0.5, 2.5)
	var pose := canvas_transform(window_size, degrees)
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	control.pivot_offset = Vector2.ZERO
	control.size = logical_size(window_size, degrees) / factor
	control.scale = Vector2(factor, factor)
	control.rotation = deg_to_rad(float(normalize(degrees)))
	control.position = pose.origin
