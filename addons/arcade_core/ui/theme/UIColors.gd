extends RefCounted
class_name AC_UIColors

const PRIMARY_COLOR: Color = Color(0.14, 0.76, 1.0, 1.0)
const SECONDARY_COLOR: Color = Color(0.22, 0.34, 0.78, 1.0)
const ACCENT_COLOR: Color = Color(0.98, 0.66, 0.24, 1.0)
const PANEL_BACKGROUND: Color = Color(0.05, 0.11, 0.23, 0.62)
const GLOW_COLOR: Color = Color(0.42, 0.86, 1.0, 1.0)
const TEXT_PRIMARY: Color = Color(0.96, 0.99, 1.0, 1.0)
const TEXT_MUTED: Color = Color(0.73, 0.84, 0.96, 1.0)
const PANEL_EDGE: Color = Color(0.80, 0.93, 1.0, 0.34)

static func primary_button_fill() -> Color:
	return PRIMARY_COLOR.darkened(0.18)

static func primary_button_edge() -> Color:
	return PRIMARY_COLOR.lightened(0.32)

static func secondary_button_fill() -> Color:
	return SECONDARY_COLOR.darkened(0.26)

static func secondary_button_edge() -> Color:
	return SECONDARY_COLOR.lightened(0.30)
