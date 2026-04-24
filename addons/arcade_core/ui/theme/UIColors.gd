extends RefCounted
class_name AC_UIColors

const PRIMARY_COLOR: Color = Color(0.23, 0.88, 1.0, 1.0)
const SECONDARY_COLOR: Color = Color(0.16, 0.20, 0.34, 1.0)
const ACCENT_COLOR: Color = Color(0.98, 0.70, 0.30, 1.0)
const ACCENT_HOT: Color = Color(1.0, 0.44, 0.76, 1.0)
const PANEL_BACKGROUND: Color = Color(0.04, 0.06, 0.11, 0.78)
const PANEL_BACKGROUND_ALT: Color = Color(0.08, 0.10, 0.17, 0.92)
const UTILITY_SURFACE: Color = Color(0.10, 0.13, 0.21, 0.88)
const GLOW_COLOR: Color = Color(0.28, 0.88, 1.0, 1.0)
const TEXT_PRIMARY: Color = Color(0.95, 0.98, 1.0, 1.0)
const TEXT_MUTED: Color = Color(0.72, 0.82, 0.95, 1.0)
const PANEL_EDGE: Color = Color(0.68, 0.90, 1.0, 0.34)
const BADGE_FILL: Color = Color(0.98, 0.70, 0.30, 1.0)
const BADGE_EDGE: Color = Color(1.0, 0.94, 0.80, 0.94)
const CHIP_FILL: Color = Color(0.10, 0.14, 0.22, 0.88)
const CHIP_EDGE: Color = Color(0.58, 0.86, 1.0, 0.28)

static func primary_button_fill() -> Color:
	return ACCENT_COLOR.darkened(0.04)

static func primary_button_edge() -> Color:
	return BADGE_EDGE

static func secondary_button_fill() -> Color:
	return PANEL_BACKGROUND_ALT

static func secondary_button_edge() -> Color:
	return PRIMARY_COLOR.lightened(0.18)

static func utility_button_fill() -> Color:
	return UTILITY_SURFACE

static func utility_button_edge() -> Color:
	return PANEL_EDGE

static func glass_tint() -> Color:
	return PANEL_BACKGROUND

static func glass_edge() -> Color:
	return PANEL_EDGE

static func glass_glow() -> Color:
	return GLOW_COLOR
