extends Control

@onready var title_label: Label = $Root/PanelShell/Panel/Content/VBox/Title
@onready var primary_cta: Button = $Root/PanelShell/Panel/Content/VBox/PrimaryCTA/StartButton
@onready var leaderboard_button: Button = $Root/PanelShell/Panel/Content/VBox/SecondaryOptions/OptionRow/LeaderboardButton
@onready var daily_button: Button = $Root/PanelShell/Panel/Content/VBox/SecondaryOptions/OptionRow/DailyButton
@onready var mode_primary_button: Button = $Root/PanelShell/Panel/Content/VBox/ModeSection/ModeButtons/ModePrimaryButton
@onready var mode_secondary_button: Button = $Root/PanelShell/Panel/Content/VBox/ModeSection/ModeButtons/ModeSecondaryButton
@onready var profile_button: Button = $Root/TopBar/ProfileButton
@onready var shop_button: Button = $Root/TopBar/ShopButton
@onready var settings_button: Button = $Root/TopBar/SettingsButton

func set_title(text_value: String) -> void:
	title_label.text = text_value
