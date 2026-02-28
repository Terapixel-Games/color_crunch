extends Resource
class_name MonetizationConfig

@export var ads_enabled: bool = true
@export var use_mock_ads: bool = true
@export var interstitial_every_n_runs: int = 4
@export var rewarded_continue_limit_per_run: int = 1
@export var rewarded_score_multiplier: float = 2.0
@export var ad_retry_attempts: int = 2
@export var ad_retry_interval_seconds: float = 0.35
@export var ad_preload_poll_seconds: float = 1.25