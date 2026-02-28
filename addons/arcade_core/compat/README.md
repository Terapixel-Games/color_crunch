# Compatibility Helpers

`SaveStoreCompat.gd` provides a lightweight adapter for projects migrating from
legacy save APIs to `SaveManager`.

Common mappings:

- `set_high_score()` / `get_high_score()`
- `increment_games_played()` / `get_games_played()`
- `get_setting()` / `set_setting()`
- `import_legacy_save(path, high_score_key, games_played_key)`

`AdManager` also includes:

- `show_rewarded_continue()` (alias of `show_rewarded_for_powerup()`)
