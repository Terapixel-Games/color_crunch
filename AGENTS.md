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
