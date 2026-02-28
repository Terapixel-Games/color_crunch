class_name AC_ParallaxLayer
extends Node2D
## Lightweight tiled parallax layer with optional texture fallback generation.

var velocity: Vector2 = Vector2.ZERO
var layer_scale: float = 1.0
var tint: Color = Color.WHITE
var alpha: float = 1.0

var _scroll: Vector2 = Vector2.ZERO
var _viewport_size: Vector2 = Vector2(1080.0, 1920.0)
var _sprite: Sprite2D
var _texture: Texture2D

static var _fallback_texture: Texture2D

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.region_enabled = true
	add_child(_sprite)
	if _texture == null:
		_texture = _get_fallback_texture()
	_apply_visuals()
	_refresh_region()

func configure(layer_data: Dictionary, viewport_size: Vector2) -> void:
	velocity = layer_data.get("velocity", Vector2.ZERO)
	layer_scale = maxf(0.01, float(layer_data.get("scale", 1.0)))
	alpha = clampf(float(layer_data.get("alpha", 1.0)), 0.0, 1.0)
	tint = Color.from_string(str(layer_data.get("tint", "#ffffff")), Color.WHITE)
	set_viewport_size(viewport_size)
	set_texture_path(str(layer_data.get("texture_path", "")))
	_apply_visuals()
	_refresh_region()

func set_texture_path(texture_path: String) -> void:
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		_texture = _get_fallback_texture()
	else:
		var loaded := load(texture_path)
		if loaded is Texture2D:
			_texture = loaded
		else:
			_texture = _get_fallback_texture()
	_apply_visuals()
	_refresh_region()

func set_viewport_size(size: Vector2) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_viewport_size = size
	_refresh_region()

func set_intensity(v: float) -> void:
	var t := clampf(v, 0.0, 1.0)
	_sprite.modulate = Color(tint.r, tint.g, tint.b, alpha * lerpf(0.75, 1.0, t))

func tick(delta: float, speed_multiplier: float = 1.0) -> void:
	if _sprite == null:
		return
	_scroll += velocity * speed_multiplier * delta
	_wrap_scroll()
	_refresh_region()

func _apply_visuals() -> void:
	if _sprite == null:
		return
	_sprite.texture = _texture
	_sprite.scale = Vector2.ONE * layer_scale
	_sprite.modulate = Color(tint.r, tint.g, tint.b, alpha)

func _refresh_region() -> void:
	if _sprite == null or _texture == null:
		return
	var source_size := (_viewport_size / layer_scale) + Vector2(256.0, 256.0)
	_sprite.position = Vector2(-128.0, -128.0)
	_sprite.region_rect = Rect2(_scroll, source_size)

func _wrap_scroll() -> void:
	if _texture == null:
		return
	var tex_size := _texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	_scroll.x = fposmod(_scroll.x, tex_size.x)
	_scroll.y = fposmod(_scroll.y, tex_size.y)

static func _get_fallback_texture() -> Texture2D:
	if _fallback_texture != null:
		return _fallback_texture

	var width := 256
	var height := 256
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 17767

	for i in range(88):
		var x := rng.randi_range(0, width - 1)
		var y := rng.randi_range(0, height - 1)
		var brightness := rng.randf_range(0.55, 1.0)
		var c := Color(0.7 * brightness, 0.8 * brightness, 1.0 * brightness, rng.randf_range(0.2, 0.9))
		image.set_pixel(x, y, c)
		if x + 1 < width:
			image.set_pixel(x + 1, y, c * Color(1, 1, 1, 0.55))
		if y + 1 < height:
			image.set_pixel(x, y + 1, c * Color(1, 1, 1, 0.45))

	_fallback_texture = ImageTexture.create_from_image(image)
	return _fallback_texture
