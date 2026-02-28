extends RefCounted
class_name ArcadePlayLayoutSystem

enum Mode {
    SQUARE_CENTERED,
    ROTATE_TO_LANDSCAPE
}

static func compute_layout(
        viewport_size: Vector2,
        layout_mode: int,
        reference_size: Vector2,
        outer_margin: float,
        min_size: Vector2
    ) -> Dictionary:
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return {
            "play_bounds": Rect2(),
            "play_scale": 1.0,
            "rig_position": Vector2.ZERO,
            "rig_rotation": 0.0,
            "rig_scale": Vector2.ONE,
            "is_landscape": false,
        }

    match layout_mode:
        Mode.ROTATE_TO_LANDSCAPE:
            return _compute_rotating_layout(viewport_size, reference_size)
        _:
            return _compute_square_layout(viewport_size, reference_size, outer_margin, min_size)

static func should_use_side_hud(viewport_size: Vector2, trigger_aspect: float) -> bool:
    if viewport_size.y <= 0.0:
        return false
    return viewport_size.x / viewport_size.y >= max(0.1, trigger_aspect)

static func _compute_square_layout(
        viewport_size: Vector2,
        reference_size: Vector2,
        outer_margin: float,
        min_size: Vector2
    ) -> Dictionary:
    var margin: float = max(0.0, outer_margin)
    var available_width: float = max(min_size.x, viewport_size.x - (margin * 2.0))
    var available_height: float = max(min_size.y, viewport_size.y - (margin * 2.0))
    var square_size: float = max(1.0, min(available_width, available_height))
    var play_pos := Vector2(
        (viewport_size.x - square_size) * 0.5,
        (viewport_size.y - square_size) * 0.5
    )
    var reference_edge: float = max(1.0, min(reference_size.x, reference_size.y))
    return {
        "play_bounds": Rect2(play_pos, Vector2(square_size, square_size)),
        "play_scale": square_size / reference_edge,
        "rig_position": Vector2.ZERO,
        "rig_rotation": 0.0,
        "rig_scale": Vector2.ONE,
        "is_landscape": viewport_size.x > viewport_size.y,
    }

static func _compute_rotating_layout(viewport_size: Vector2, reference_size: Vector2) -> Dictionary:
    var ref_size := Vector2(max(1.0, reference_size.x), max(1.0, reference_size.y))
    var is_landscape: bool = viewport_size.x > viewport_size.y
    var fit_scale: float = 1.0
    var rotation: float = 0.0

    if is_landscape:
        # Rotate gameplay in widescreen so vertical-flow games can become horizontal.
        rotation = PI * 0.5
        fit_scale = max(viewport_size.x / ref_size.y, viewport_size.y / ref_size.x)
    else:
        rotation = 0.0
        fit_scale = min(viewport_size.x / ref_size.x, viewport_size.y / ref_size.y)

    fit_scale = max(0.0001, fit_scale)
    var center_offset: Vector2 = (ref_size * 0.5).rotated(rotation) * fit_scale
    var rig_position: Vector2 = (viewport_size * 0.5) - center_offset
    var scaled_rect_size: Vector2 = ref_size * fit_scale
    var play_bounds: Rect2

    if is_landscape:
        play_bounds = Rect2(
            Vector2(
                (viewport_size.x - scaled_rect_size.y) * 0.5,
                (viewport_size.y - scaled_rect_size.x) * 0.5
            ),
            Vector2(scaled_rect_size.y, scaled_rect_size.x)
        )
    else:
        play_bounds = Rect2(
            Vector2(
                (viewport_size.x - scaled_rect_size.x) * 0.5,
                (viewport_size.y - scaled_rect_size.y) * 0.5
            ),
            scaled_rect_size
        )

    return {
        "play_bounds": play_bounds,
        "play_scale": fit_scale,
        "rig_position": rig_position,
        "rig_rotation": rotation,
        "rig_scale": Vector2.ONE * fit_scale,
        "is_landscape": is_landscape,
    }
