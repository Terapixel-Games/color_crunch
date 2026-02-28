extends Node

const DAY_SECONDS := 86400

func _today_key() -> String:
    var d := Time.get_date_dict_from_system()
    return "%04d-%02d-%02d" % [d.year, d.month, d.day]

func _days_between(a: String, b: String) -> int:
    var da := Time.get_datetime_dict_from_system()
    var db := Time.get_datetime_dict_from_system()

    if a != "":
        var pa := a.split("-")
        if pa.size() == 3:
            da.year = int(pa[0])
            da.month = int(pa[1])
            da.day = int(pa[2])

    if b != "":
        var pb := b.split("-")
        if pb.size() == 3:
            db.year = int(pb[0])
            db.month = int(pb[1])
            db.day = int(pb[2])

    var ja := Time.get_unix_time_from_datetime_dict(da) / DAY_SECONDS
    var jb := Time.get_unix_time_from_datetime_dict(db) / DAY_SECONDS
    return int(jb - ja)

func get_streak_days() -> int:
    return int(SaveManager.data.get("streaks", {}).get("days", 0))

func is_streak_at_risk() -> bool:
    return int(SaveManager.data.get("streaks", {}).get("at_risk", 0)) > 0

func get_streak_at_risk_days() -> int:
    return int(SaveManager.data.get("streaks", {}).get("at_risk", 0))

func record_game_play(date_key: String = "") -> void:
    if date_key == "":
        date_key = _today_key()

    var streaks: Dictionary = SaveManager.data.get("streaks", {})
    var last := str(streaks.get("last_play_date", ""))

    if last == "":
        streaks["days"] = 1
        streaks["at_risk"] = 0
        streaks["last_play_date"] = date_key
        SaveManager.flush()
        return

    if last == date_key:
        return

    var delta_days := _days_between(last, date_key)
    if delta_days == 1:
        streaks["days"] = int(streaks.get("days", 0)) + 1
        streaks["at_risk"] = 0
        streaks["last_play_date"] = date_key
        SaveManager.flush()
        return

    if delta_days > 1:
        streaks["at_risk"] = int(streaks.get("days", 0))
        streaks["days"] = 0
        streaks["last_play_date"] = date_key
        SaveManager.flush()

func apply_rewarded_save(date_key: String = "") -> void:
    if not is_streak_at_risk():
        return
    if date_key == "":
        date_key = _today_key()

    var streaks: Dictionary = SaveManager.data.get("streaks", {})
    streaks["days"] = get_streak_at_risk_days()
    streaks["at_risk"] = 0
    streaks["last_play_date"] = date_key
    SaveManager.flush()
