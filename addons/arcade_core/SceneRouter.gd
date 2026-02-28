extends Node

# Minimal helper to swap scenes with optional fade later.
func goto(scene_path: String) -> void:
    var packed := load(scene_path)
    if packed == null:
        push_error("Scene not found: %s" % scene_path)
        return
    get_tree().change_scene_to_packed(packed)
