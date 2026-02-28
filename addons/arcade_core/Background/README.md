# ArcadeCore Background Effects Pack

## Overview
`AC_BackgroundController` provides a profile-driven background stack for Godot 4.x arcade games.

Layers (bottom to top):
1. Gradient warp
2. Parallax depth layers
3. Flow-field particles (MultiMesh)
4. Grid warp (optional)
5. Light sweep (optional)
6. Color grade (subtle combo modulation)

All layers render inside a dedicated `CanvasLayer` configured behind gameplay.

## Quick Start
```gdscript
var bg := AC_BackgroundController.new()
add_child(bg)
bg.load_profile("neon_arcade")
bg.set_tier(1)
```

## Runtime API
- `load_profile(profile_name: String)`
- `apply_profile(profile: AC_BackgroundProfile)`
- `set_combo_intensity(v: float)`
- `set_tier(t: int)`
- `trigger_powerup_pulse(strength: float = 1.0)`
- `set_enabled_layer(layer_id: String, enabled: bool)`
- `set_pause_background(paused: bool)`

Signals:
- `profile_loaded(name)`
- `tier_changed(tier)`
- `performance_throttled(new_count)`

## Profile File
Profiles are loaded from:
`res://addons/arcade_core/Background/profiles/background_profiles.json`

Top-level schema:
```json
{
  "profiles": {
    "profile_name": {
      "gradient": { ... },
      "parallax_layers": [ ... ],
      "flow_particles": { ... },
      "grid": { ... },
      "sweep": { ... },
      "tiers": { ... }
    }
  }
}
```

Missing values are safely defaulted.

## Performance Notes
- Flow particles use one `MultiMeshInstance2D`.
- No per-particle nodes.
- Adaptive throttling reduces particle count if FPS drops below 55 for sustained intervals.

## Demo
Open:
`res://addons/arcade_core/Demo/BackgroundDemo.tscn`

Use the UI to switch profiles, tier, combo intensity, and layer toggles.
