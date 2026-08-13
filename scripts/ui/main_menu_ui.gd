extends Control

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var subtitle_label: Label = $VBoxContainer/SubtitleLabel
@onready var version_label: Label = $VBoxContainer/VersionLabel

func _ready() -> void:
    # 设置标题
    title_label.text = "华夏模拟人生"
    subtitle_label.text = "西周 · 士族篇"
    version_label.text = "v0.1.0 — 士族开局"

    # 更新按钮样式为高亮，提供更好的视觉反馈
    start_button.texture = $Resource/start_button_highlight

    # 连接按钮信号
    start_button.pressed.connect(_on_start_pressed)

    # 初始化游戏状态
    GameState.game_started = false
    GameState.current_year = DynastyManager.get_year_start()
    GameState.current_dynasty_id = DynastyManager.get_dynasty_id()

func _on_start_pressed() -> void:
    # 加载角色创建场景
    get_tree().change_scene_to_file("res://scenes/character_create.tscn")
