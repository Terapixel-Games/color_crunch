extends GPUParticles2D

var _viewport_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	emitting = true
	_update_layout()

func _process(_delta: float) -> void:
	var next_size := get_viewport_rect().size
	if next_size != _viewport_size:
		_update_layout()

func _update_layout() -> void:
	_viewport_size = get_viewport_rect().size
	position = _viewport_size * 0.5
	var material := process_material as ParticleProcessMaterial
	if material == null:
		return
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(_viewport_size.x * 0.5, _viewport_size.y * 0.5, 0.0)
