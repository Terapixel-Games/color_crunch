# Agent Guardrails

## Modal And Input Bugs
- Do not set UI to `PROCESS_MODE_WHEN_PAUSED` unless the scene is only shown while `get_tree().paused == true`.
- For overlays used on non-paused scenes (for example results/menu modals), use default processing or `PROCESS_MODE_ALWAYS`.
- If hover works but click does not, check these first:
  - node `process_mode`
  - `mouse_filter` on full-screen parents
  - whether an overlay `gui_input` handler is consuming events
- Recommended modal input routing:
  - modal root: `MOUSE_FILTER_PASS`
  - dim/backdrop: `MOUSE_FILTER_STOP` (outside click dismiss)
  - layout containers: `MOUSE_FILTER_IGNORE`
  - actionable controls (buttons): `MOUSE_FILTER_STOP`
- Keep a unit test that instantiates the modal and verifies:
  - `process_mode`
  - modal `mouse_filter` contract
  - close button press frees the modal

## Styling Cues
- Any `Control` that animates `scale` or `rotation` must set `pivot_offset = size * 0.5`.
- Refresh animated control pivots on `NOTIFICATION_RESIZED` (layout changes can shift pivots).
- For modal layouts, verify both mobile portrait and desktop landscape so CTA buttons stay fully inside the panel and centered.
- Keep button interaction tests with both hover and click behavior; hover-only success can hide input routing regressions.
- Prefer atlas sprite-sheet icons over unicode glyph text for controls (`Pause`, arrows, powerups) to avoid font/render inconsistencies across devices.

## Modal Layout Contract
- Build modals with container layout only: `Backdrop` + frosted `Panel` + main `VBox`.
- Use explicit `TopInset` and `BottomInset` controls inside the modal `VBox`; do not rely on container offsets for vertical padding.
- Enforce equal effective inside spacing on all sides:
  - side inset = panel side margin + content inset
  - top inset = bottom inset = side inset
- Modal panel height must shrink to content + insets, capped by viewport height; avoid fixed tall panel heights.
- If content exceeds cap, only the modal body scrolls (`ScrollContainer` expands; header/footer stay visible).
- Footer action buttons (for example `Close`, `Refresh Wallet`) must stay inside the glass panel.
