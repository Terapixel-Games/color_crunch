class_name AC_BackgroundProfile
extends RefCounted
## Typed background profile model with defaults and JSON coercion helpers.

const DEFAULT_GRADIENT := {
	"base_color_a": "#101825",
	"base_color_b": "#2a1b3f",
	"hue_speed": 0.012,
	"pulse_intensity": 0.06,
	"pulse_speed": 0.22,
	"vignette": 0.2
}

const DEFAULT_FLOW := {
	"enabled": true,
	"count": 220,
	"min_count": 90,
	"speed": 36.0,
	"alpha": 0.24,
	"palette": ["#8fd4ff", "#b8a6ff", "#8cf2d0"],
	"scale_min": 0.45,
	"scale_max": 1.25,
	"bounds_padding": 80.0
}

const DEFAULT_GRID := {
	"enabled": false,
	"opacity": 0.12,
	"warp_amount": 0.06,
	"warp_speed": 0.35,
	"spacing": 52.0,
	"thickness": 0.045,
	"color": "#56caff"
}

const DEFAULT_SWEEP := {
	"enabled": true,
	"opacity": 0.08,
	"interval_min": 20.0,
	"interval_max": 40.0,
	"speed": 0.45
}

const DEFAULT_TIER_OVERRIDES := {
	"1": {
		"parallax_speed_mult": 0.85,
		"flow_count_mult": 0.45,
		"flow_speed_mult": 0.75,
		"hue_speed_mult": 0.65,
		"combo_reactive": false,
		"grid_enabled": false
	},
	"2": {
		"parallax_speed_mult": 0.95,
		"flow_count_mult": 0.65,
		"flow_speed_mult": 0.85,
		"hue_speed_mult": 0.95,
		"combo_reactive": false,
		"grid_enabled": false
	},
	"3": {
		"parallax_speed_mult": 1.15,
		"flow_count_mult": 0.85,
		"flow_speed_mult": 1.0,
		"hue_speed_mult": 1.0,
		"combo_reactive": false,
		"grid_enabled": false
	},
	"4": {
		"parallax_speed_mult": 1.22,
		"flow_count_mult": 1.0,
		"flow_speed_mult": 1.08,
		"hue_speed_mult": 1.12,
		"combo_reactive": true,
		"grid_enabled": false
	},
	"5": {
		"parallax_speed_mult": 1.3,
		"flow_count_mult": 1.14,
		"flow_speed_mult": 1.2,
		"hue_speed_mult": 1.2,
		"combo_reactive": true,
		"grid_enabled": true,
		"grid_warp_boost": 0.22
	}
}

var profile_name: String = ""
var gradient: Dictionary = DEFAULT_GRADIENT.duplicate(true)
var parallax_layers: Array[Dictionary] = []
var flow_particles: Dictionary = DEFAULT_FLOW.duplicate(true)
var grid: Dictionary = DEFAULT_GRID.duplicate(true)
var sweep: Dictionary = DEFAULT_SWEEP.duplicate(true)
var tiers: Dictionary = DEFAULT_TIER_OVERRIDES.duplicate(true)

static func from_dict(name: String, data: Dictionary):
	var profile = load("res://addons/arcade_core/Background/AC_BackgroundProfile.gd").new()
	profile.profile_name = name
	profile.gradient = _parse_gradient(data.get("gradient", {}))
	profile.parallax_layers = _parse_parallax_layers(data.get("parallax_layers", []))
	profile.flow_particles = _parse_flow(data.get("flow_particles", {}))
	profile.grid = _parse_grid(data.get("grid", {}))
	profile.sweep = _parse_sweep(data.get("sweep", {}))
	profile.tiers = _parse_tiers(data.get("tiers", {}))
	return profile

static func builtin_profiles() -> Dictionary:
	return {
		"calm_puzzle": from_dict("calm_puzzle", {
			"gradient": {
				"base_color_a": "#0f1a27",
				"base_color_b": "#19324e",
				"hue_speed": 0.008,
				"pulse_intensity": 0.04,
				"pulse_speed": 0.16,
				"vignette": 0.25
			},
			"parallax_layers": [
				{"velocity": [2.0, 8.0], "alpha": 0.2, "tint": "#9ebfff", "scale": 1.0},
				{"velocity": [4.0, 16.0], "alpha": 0.16, "tint": "#b7d6ff", "scale": 1.2},
				{"velocity": [6.0, 24.0], "alpha": 0.12, "tint": "#d8edff", "scale": 1.5}
			],
			"flow_particles": {
				"enabled": true,
				"count": 130,
				"min_count": 50,
				"speed": 24,
				"alpha": 0.16,
				"palette": ["#9fd1ff", "#a8ffe2", "#c2c9ff"]
			},
			"grid": {"enabled": false},
			"sweep": {"enabled": false}
		}),
		"neon_arcade": from_dict("neon_arcade", {
			"gradient": {
				"base_color_a": "#1c1638",
				"base_color_b": "#08364a",
				"hue_speed": 0.018,
				"pulse_intensity": 0.08,
				"pulse_speed": 0.24,
				"vignette": 0.22
			},
			"parallax_layers": [
				{"velocity": [8.0, 14.0], "alpha": 0.25, "tint": "#b86dff", "scale": 1.1},
				{"velocity": [14.0, 24.0], "alpha": 0.2, "tint": "#5cc4ff", "scale": 1.35},
				{"velocity": [22.0, 36.0], "alpha": 0.16, "tint": "#73ffe8", "scale": 1.6}
			],
			"flow_particles": {
				"enabled": true,
				"count": 260,
				"min_count": 90,
				"speed": 48,
				"alpha": 0.26,
				"palette": ["#6fd6ff", "#be91ff", "#7effd8"]
			},
			"grid": {
				"enabled": true,
				"opacity": 0.13,
				"warp_amount": 0.08,
				"warp_speed": 0.6,
				"spacing": 58,
				"thickness": 0.042,
				"color": "#57d2ff"
			},
			"sweep": {"enabled": true, "opacity": 0.08, "interval_min": 22.0, "interval_max": 34.0, "speed": 0.54}
		}),
		"synth_grid": from_dict("synth_grid", {
			"gradient": {
				"base_color_a": "#120f26",
				"base_color_b": "#2f1840",
				"hue_speed": 0.013,
				"pulse_intensity": 0.07,
				"pulse_speed": 0.2,
				"vignette": 0.18
			},
			"parallax_layers": [
				{"velocity": [3.0, 6.0], "alpha": 0.22, "tint": "#f58dff", "scale": 1.0},
				{"velocity": [8.0, 12.0], "alpha": 0.18, "tint": "#8a9dff", "scale": 1.25},
				{"velocity": [14.0, 22.0], "alpha": 0.13, "tint": "#64edff", "scale": 1.55}
			],
			"flow_particles": {
				"enabled": true,
				"count": 180,
				"min_count": 70,
				"speed": 34,
				"alpha": 0.2,
				"palette": ["#ff93f2", "#8dd0ff", "#8fffd5"]
			},
			"grid": {
				"enabled": true,
				"opacity": 0.18,
				"warp_amount": 0.11,
				"warp_speed": 0.7,
				"spacing": 42,
				"thickness": 0.06,
				"color": "#ff89f0"
			},
			"sweep": {"enabled": true, "opacity": 0.06, "interval_min": 28.0, "interval_max": 44.0, "speed": 0.42}
		})
	}

func get_tier_settings(tier: int) -> Dictionary:
	var clamped_tier: int = maxi(1, tier)
	var base_key: String = str(mini(clamped_tier, 5))
	var settings: Dictionary = {}
	if DEFAULT_TIER_OVERRIDES.has(base_key):
		settings = (DEFAULT_TIER_OVERRIDES[base_key] as Dictionary).duplicate(true)
	if clamped_tier > 5:
		settings["parallax_speed_mult"] = float(settings.get("parallax_speed_mult", 1.3)) + float(clamped_tier - 5) * 0.04
		settings["flow_count_mult"] = float(settings.get("flow_count_mult", 1.14)) + float(clamped_tier - 5) * 0.03
		settings["flow_speed_mult"] = float(settings.get("flow_speed_mult", 1.2)) + float(clamped_tier - 5) * 0.02
		settings["hue_speed_mult"] = float(settings.get("hue_speed_mult", 1.2)) + float(clamped_tier - 5) * 0.02
		settings["combo_reactive"] = true
		settings["grid_enabled"] = true
	if tiers.has(str(clamped_tier)):
		settings.merge(tiers[str(clamped_tier)], true)
	return settings

static func _parse_gradient(raw: Variant) -> Dictionary:
	var out: Dictionary = DEFAULT_GRADIENT.duplicate(true)
	if raw is Dictionary:
		out["base_color_a"] = str(raw.get("base_color_a", out["base_color_a"]))
		out["base_color_b"] = str(raw.get("base_color_b", out["base_color_b"]))
		out["hue_speed"] = clampf(float(raw.get("hue_speed", out["hue_speed"])), 0.0, 2.0)
		out["pulse_intensity"] = clampf(float(raw.get("pulse_intensity", out["pulse_intensity"])), 0.0, 1.0)
		out["pulse_speed"] = clampf(float(raw.get("pulse_speed", out["pulse_speed"])), 0.0, 4.0)
		out["vignette"] = clampf(float(raw.get("vignette", out["vignette"])), 0.0, 1.0)
	return out

static func _parse_parallax_layers(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if raw is Array:
		for entry in raw:
			if not (entry is Dictionary):
				continue
			var velocity: Vector2 = Vector2.ZERO
			var vel_val: Variant = entry.get("velocity", [0.0, 0.0])
			if vel_val is Array and vel_val.size() >= 2:
				velocity = Vector2(float(vel_val[0]), float(vel_val[1]))
			elif vel_val is Vector2:
				velocity = vel_val
			out.append({
				"texture_path": str(entry.get("texture_path", "")),
				"velocity": velocity,
				"tint": str(entry.get("tint", "#ffffff")),
				"alpha": clampf(float(entry.get("alpha", 0.2)), 0.0, 1.0),
				"scale": maxf(0.01, float(entry.get("scale", 1.0)))
			})
	return out

static func _parse_flow(raw: Variant) -> Dictionary:
	var out: Dictionary = DEFAULT_FLOW.duplicate(true)
	if raw is Dictionary:
		out["enabled"] = bool(raw.get("enabled", out["enabled"]))
		out["count"] = maxi(0, int(raw.get("count", out["count"])))
		out["min_count"] = maxi(0, int(raw.get("min_count", out["min_count"])))
		out["speed"] = maxf(0.0, float(raw.get("speed", out["speed"])))
		out["alpha"] = clampf(float(raw.get("alpha", out["alpha"])), 0.0, 1.0)
		out["scale_min"] = maxf(0.05, float(raw.get("scale_min", out["scale_min"])))
		out["scale_max"] = maxf(out["scale_min"], float(raw.get("scale_max", out["scale_max"])))
		out["bounds_padding"] = maxf(0.0, float(raw.get("bounds_padding", out["bounds_padding"])))
		var palette_val: Variant = raw.get("palette", out["palette"])
		var palette: Array = []
		if palette_val is Array:
			for c in palette_val:
				palette.append(str(c))
		if palette.is_empty():
			palette = out["palette"].duplicate()
		out["palette"] = palette
	return out

static func _parse_grid(raw: Variant) -> Dictionary:
	var out: Dictionary = DEFAULT_GRID.duplicate(true)
	if raw is Dictionary:
		out["enabled"] = bool(raw.get("enabled", out["enabled"]))
		out["opacity"] = clampf(float(raw.get("opacity", out["opacity"])), 0.0, 1.0)
		out["warp_amount"] = clampf(float(raw.get("warp_amount", out["warp_amount"])), 0.0, 1.5)
		out["warp_speed"] = clampf(float(raw.get("warp_speed", out["warp_speed"])), 0.0, 5.0)
		out["spacing"] = maxf(8.0, float(raw.get("spacing", out["spacing"])))
		out["thickness"] = clampf(float(raw.get("thickness", out["thickness"])), 0.001, 0.45)
		out["color"] = str(raw.get("color", out["color"]))
	return out

static func _parse_sweep(raw: Variant) -> Dictionary:
	var out: Dictionary = DEFAULT_SWEEP.duplicate(true)
	if raw is Dictionary:
		out["enabled"] = bool(raw.get("enabled", out["enabled"]))
		out["opacity"] = clampf(float(raw.get("opacity", out["opacity"])), 0.0, 1.0)
		out["interval_min"] = maxf(1.0, float(raw.get("interval_min", out["interval_min"])))
		out["interval_max"] = maxf(out["interval_min"], float(raw.get("interval_max", out["interval_max"])))
		out["speed"] = maxf(0.01, float(raw.get("speed", out["speed"])))
	return out

static func _parse_tiers(raw: Variant) -> Dictionary:
	var out: Dictionary = DEFAULT_TIER_OVERRIDES.duplicate(true)
	if raw is Dictionary:
		for k in raw.keys():
			if not (raw[k] is Dictionary):
				continue
			var key: String = str(k)
			if not out.has(key):
				out[key] = {}
			out[key].merge(raw[k], true)
	return out
