class_name AC_FlowFieldParticles
extends Node2D
## Flow-field style particle drift rendered via a single MultiMeshInstance2D.

signal throttled(new_count: int)

var enabled_effect: bool = true
var target_count: int = 220
var min_count: int = 90
var runtime_count: int = 220
var active_count: int = 220
var base_speed: float = 36.0
var base_alpha: float = 0.24
var scale_min: float = 0.45
var scale_max: float = 1.25
var bounds_padding: float = 80.0
var speed_multiplier: float = 1.0
var intensity: float = 0.0

var _time_accum: float = 0.0
var _fps_low_time: float = 0.0
var _fps_high_time: float = 0.0
var _palette: Array[Color] = [Color(0.56, 0.83, 1.0), Color(0.72, 0.65, 1.0), Color(0.55, 0.95, 0.82)]
var _bounds: Rect2 = Rect2(-80.0, -80.0, 1240.0, 2080.0)

var _positions: Array[Vector2] = []
var _phases: PackedFloat32Array = PackedFloat32Array()
var _scales: PackedFloat32Array = PackedFloat32Array()
var _color_ids: PackedInt32Array = PackedInt32Array()

var _rng := RandomNumberGenerator.new()
var _mesh_instance: MultiMeshInstance2D
var _multimesh: MultiMesh

static var _particle_texture: Texture2D

func _ready() -> void:
	_rng.randomize()
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true
	_multimesh.mesh = QuadMesh.new()
	(_multimesh.mesh as QuadMesh).size = Vector2(12.0, 12.0)

	_mesh_instance = MultiMeshInstance2D.new()
	_mesh_instance.multimesh = _multimesh
	_mesh_instance.texture = _get_particle_texture()
	_mesh_instance.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_mesh_instance)

	_resize_storage(runtime_count)
	_recalculate_visible_count()
	_commit_all_instances()

func configure(config: Dictionary, viewport_size: Vector2) -> void:
	enabled_effect = bool(config.get("enabled", true))
	target_count = maxi(0, int(config.get("count", target_count)))
	min_count = maxi(0, int(config.get("min_count", min_count)))
	runtime_count = maxi(min_count, target_count)
	base_speed = maxf(0.0, float(config.get("speed", base_speed)))
	base_alpha = clampf(float(config.get("alpha", base_alpha)), 0.0, 1.0)
	scale_min = maxf(0.05, float(config.get("scale_min", scale_min)))
	scale_max = maxf(scale_min, float(config.get("scale_max", scale_max)))
	bounds_padding = maxf(0.0, float(config.get("bounds_padding", bounds_padding)))
	_parse_palette(config.get("palette", []))
	set_bounds_from_viewport(viewport_size)
	_resize_storage(runtime_count)
	_recalculate_visible_count()
	_commit_all_instances()
	visible = enabled_effect

func set_bounds_from_viewport(viewport_size: Vector2) -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	_bounds = Rect2(
		Vector2(-bounds_padding, -bounds_padding),
		viewport_size + Vector2(bounds_padding, bounds_padding) * 2.0
	)

func set_enabled_effect(next_enabled: bool) -> void:
	enabled_effect = next_enabled
	visible = enabled_effect
	if _multimesh != null:
		_multimesh.visible_instance_count = active_count if enabled_effect else 0

func set_intensity(v: float) -> void:
	intensity = clampf(v, 0.0, 1.0)
	_recalculate_visible_count()

func set_speed_multiplier(v: float) -> void:
	speed_multiplier = maxf(0.0, v)

func tick(delta: float) -> void:
	if not enabled_effect:
		return
	if _multimesh == null:
		return

	_time_accum += delta
	_update_adaptive_throttle(delta)

	var energy := lerpf(0.65, 1.0, intensity)
	var speed := base_speed * speed_multiplier * lerpf(0.8, 1.15, intensity)
	var alpha_mult := lerpf(0.72, 1.0, intensity)

	for i in range(active_count):
		var p := _positions[i]
		var phase := _phases[i]
		var field_x := sin((p.x + _time_accum * 34.0) * 0.0034 + phase) + cos((p.y - _time_accum * 22.0) * 0.0026 - phase * 1.7)
		var field_y := cos((p.x - _time_accum * 26.0) * 0.0021 + phase * 0.8) - sin((p.y + _time_accum * 18.0) * 0.0031 + phase)
		var dir := Vector2(field_x, field_y)
		if dir.length_squared() < 0.0001:
			dir = Vector2.RIGHT
		else:
			dir = dir.normalized()

		p += dir * speed * energy * delta * lerpf(0.85, 1.3, _scales[i])
		p = _wrap_point(p)
		_positions[i] = p

		var c := _palette[_color_ids[i] % _palette.size()]
		c.a = base_alpha * alpha_mult
		var size := lerpf(scale_min, scale_max, _scales[i])
		var xf := Transform2D.IDENTITY.scaled(Vector2.ONE * size)
		xf.origin = p
		_multimesh.set_instance_transform_2d(i, xf)
		_multimesh.set_instance_color(i, c)

func _update_adaptive_throttle(delta: float) -> void:
	var fps := float(Engine.get_frames_per_second())
	if fps < 55.0:
		_fps_low_time += delta
		_fps_high_time = 0.0
		if _fps_low_time >= 1.0:
			_fps_low_time = 0.0
			var reduced := maxi(min_count, int(floor(float(runtime_count) * 0.8)))
			if reduced < runtime_count:
				runtime_count = reduced
				_resize_storage(runtime_count)
				_recalculate_visible_count()
				emit_signal("throttled", runtime_count)
	elif fps > 58.0:
		_fps_high_time += delta
		_fps_low_time = 0.0
		if _fps_high_time >= 5.0 and runtime_count < target_count:
			_fps_high_time = 0.0
			var restored := mini(target_count, runtime_count + maxi(1, int(ceil(float(target_count) * 0.1))))
			runtime_count = restored
			_resize_storage(runtime_count)
			_recalculate_visible_count()
	else:
		_fps_low_time = 0.0
		_fps_high_time = 0.0

func _recalculate_visible_count() -> void:
	if _multimesh == null:
		return
	var count_range := maxi(0, runtime_count - min_count)
	active_count = mini(runtime_count, min_count + int(round(float(count_range) * intensity)))
	active_count = maxi(0, active_count)
	_multimesh.visible_instance_count = active_count if enabled_effect else 0

func _resize_storage(count: int) -> void:
	if _multimesh == null:
		return

	var prev := _positions.size()
	_positions.resize(count)
	_phases.resize(count)
	_scales.resize(count)
	_color_ids.resize(count)
	_multimesh.instance_count = count

	for i in range(prev, count):
		_positions[i] = _random_point()
		_phases[i] = _rng.randf_range(0.0, TAU)
		_scales[i] = _rng.randf()
		_color_ids[i] = _rng.randi_range(0, maxi(0, _palette.size() - 1))

func _commit_all_instances() -> void:
	if _multimesh == null:
		return
	for i in range(_positions.size()):
		var c := _palette[_color_ids[i] % _palette.size()]
		c.a = base_alpha
		var size := lerpf(scale_min, scale_max, _scales[i])
		var xf := Transform2D.IDENTITY.scaled(Vector2.ONE * size)
		xf.origin = _positions[i]
		_multimesh.set_instance_transform_2d(i, xf)
		_multimesh.set_instance_color(i, c)

func _random_point() -> Vector2:
	return Vector2(
		_rng.randf_range(_bounds.position.x, _bounds.end.x),
		_rng.randf_range(_bounds.position.y, _bounds.end.y)
	)

func _wrap_point(p: Vector2) -> Vector2:
	if p.x < _bounds.position.x:
		p.x = _bounds.end.x
	elif p.x > _bounds.end.x:
		p.x = _bounds.position.x
	if p.y < _bounds.position.y:
		p.y = _bounds.end.y
	elif p.y > _bounds.end.y:
		p.y = _bounds.position.y
	return p

func _parse_palette(raw: Variant) -> void:
	_palette.clear()
	if raw is Array:
		for c in raw:
			_palette.append(Color.from_string(str(c), Color.WHITE))
	if _palette.is_empty():
		_palette = [Color(0.56, 0.83, 1.0), Color(0.72, 0.65, 1.0), Color(0.55, 0.95, 0.82)]

static func _get_particle_texture() -> Texture2D:
	if _particle_texture != null:
		return _particle_texture

	var size := 48
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := size * 0.5
	for y in range(size):
		for x in range(size):
			var d := center.distance_to(Vector2(x, y)) / radius
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))

	_particle_texture = ImageTexture.create_from_image(image)
	return _particle_texture
