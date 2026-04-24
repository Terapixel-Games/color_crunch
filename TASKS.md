# TASKS - color_crunch

## Baseline
- [x] Project boots headless and unit tests are wired.


## Fun Scale Excellence Plan (2026-02-27)
- [x] Baseline fun-scale gap audit completed (points 1-9).
- [x] [P1] Eliminate remaining runtime warnings/resource leaks in headless runs to protect polish quality.
- [x] [P2] Expand social loop depth (weekly challenge ladder + async rival targets).

<!-- BEGIN CODEX REVIEW 2026-04-24 -->

## Automated Review - 2026-04-24

Review commands used:
- `audit_repo.ps1 -TargetRepo <game>`
- `verify_repo.ps1 -TargetRepo <game> -Suite unit -GodotBin C:\code\bin\godot.exe`
- `verify-visual-smoke.ps1 -TargetRepo <game> -GodotBin C:\code\bin\godot.exe`

Current state:
- [x] Unit verification is clean via `verify_repo.ps1 -Suite unit` (files=21 tests=75 failures=0).
- [x] 180-frame visual smoke is clean via `cc_merge_growth`.
- [x] Required ArcadeCore autoload and display contracts are satisfied.
- [x] ArcadeCore addon drift is reconciled against the canonical `ArcadeCore` source.
- [x] Premium ArcadeCore UI primitives are present.

Completed in this pass:
- [x] Hardened shared `run-tests.ps1` so compile/parse errors and nonzero Godot exits fail honestly.
- [x] Updated shared `TestRunner.gd` to register ordered project autoloads, support Node-based tests, handle gdUnit suites, dispose gdUnit runtime state, and avoid duplicate existing autoloads.
- [x] Added shared generic scenario-driver visual smoke coverage where no product-specific scenario existed.
- [x] Hardened `verify-visual-smoke.ps1` so script/parse/compile errors fail classification.
- [x] Re-ran the full 22-game unit and visual-smoke verification sweeps after fixes.

Next implementation tasks:
- [ ] Investigate remaining Godot shutdown RID/resource leak warnings from unit and visual-smoke runs.
- [ ] Re-run unit and visual-smoke verification after each fix and update this section with the result.

<!-- END CODEX REVIEW 2026-04-24 -->



