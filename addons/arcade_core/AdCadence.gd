extends Node

static func interstitial_every_n_games(streak_days: int) -> int:
    if streak_days <= 1:
        return 1
    if streak_days <= 3:
        return 2
    if streak_days <= 6:
        return 3
    if streak_days <= 13:
        return 4
    return 5
