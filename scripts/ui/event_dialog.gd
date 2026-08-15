# EventDialog.gd — 事件对话框
extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var text_label: Label = $Panel/VBoxContainer/TextLabel
@onready var choices_container: VBoxContainer = $Panel/VBoxContainer/ChoicesContainer
@onready var result_label: RichTextLabel = $Panel/VBoxContainer/ResultLabel
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

var _event_data: Dictionary = {}
var _resolved: bool = false
var _illustration_rect: TextureRect = null

func _ready() -> void:
	close_button.pressed.connect(_on_close)
	close_button.visible = false

	# 西周主题样式
	VisualConfig.style_panel(panel)
	VisualConfig.style_heading_label(title_label, 22)
	VisualConfig.style_body_label(text_label, 15)
	VisualConfig.style_button(close_button, 14)
	# 操作反馈：关闭按钮青铜样式 + 悬停/按下轻动效
	_style_feedback_button(close_button)

	# 轻动效：面板淡入（青铜浮现）
	panel.modulate.a = 0.0
	var entrance := create_tween()
	entrance.tween_property(panel, "modulate:a", 1.0, VisualConfig.TWEEN_POPUP_IN)

	_event_data = EventManager.get_current_event()
	if _event_data.is_empty():
		# 不是事件触发——等待外部调用 show_action_result() 填充内容
		return

	title_label.text = _event_data.get("title", "事件")
	text_label.text = _event_data.get("text", "")

	# ── 事件插图 ──
	var illu_path: String = _event_data.get("illustration", "")
	if not illu_path.is_empty() and ResourceLoader.exists(illu_path):
		_illustration_rect = TextureRect.new()
		_illustration_rect.name = "EventIllustration"
		_illustration_rect.texture = load(illu_path)
		_illustration_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_illustration_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_illustration_rect.custom_minimum_size = Vector2(600, 280)
		_illustration_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# 轻动效：画卷徐徐展开（淡入）。
		# 插图是 VBoxContainer 子节点，位置由容器布局接管，故只动 modulate 不动 position。
		_illustration_rect.modulate.a = 0.0
		var illu_tw := create_tween()
		illu_tw.tween_property(_illustration_rect, "modulate:a", 1.0, 0.3)

		# 插入到 VBoxContainer 的标题和正文之间
		var vbox: VBoxContainer = $Panel/VBoxContainer
		var text_idx := text_label.get_index()
		vbox.add_child(_illustration_rect)
		vbox.move_child(_illustration_rect, text_idx)

	# 创建选择按钮
	var choices = EventManager.get_current_event_choices()
	for i in range(choices.size()):
		var choice = choices[i]
		var btn = Button.new()
		btn.text = "%d. %s" % [i + 1, choice.get("text", "")]
		btn.custom_minimum_size = Vector2(600, 40)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		VisualConfig.style_button(btn, 14)
		_style_feedback_button(btn)

		# 轻动效：选项依次浮现（逐枚"竹简"落下）
		btn.modulate.a = 0.0
		var appear := create_tween()
		appear.tween_interval(0.04 * i)
		appear.tween_property(btn, "modulate:a", 1.0, VisualConfig.TWEEN_POPUP_IN)

		var idx = i
		btn.pressed.connect(_on_choice_made.bind(idx))
		choices_container.add_child(btn)

func _on_choice_made(choice_index: int) -> void:
	if _resolved:
		return

	_resolved = true

	# 操作反馈：点选后立刻禁用其余选项
	for child in choices_container.get_children():
		if child is Button:
			child.disabled = true

	# 操作反馈：高亮被选中的选项（明确"你选了哪个"）
	var chosen := choices_container.get_child(choice_index) as Button
	if chosen:
		var sel := VisualConfig.make_panel_stylebox(VisualConfig.BG_MID_BROWN, VisualConfig.GOLD, 2, 4)
		chosen.add_theme_stylebox_override("normal", sel)
		chosen.add_theme_stylebox_override("hover", sel)
		chosen.add_theme_stylebox_override("pressed", sel)
		chosen.add_theme_stylebox_override("disabled", sel)

	# 解析骰子
	var result = EventManager.resolve_choice(choice_index)
	if result.has("error"):
		result_label.text = "错误：%s" % result.error
		_show_close()
		return

	# ── 掷骰逐级揭示：先露「?」，再翻点数，最后翻结果段名 ──
	# 制造「骰子落定 / 卜筮问天」的悬念感（操作反馈 + 轻动效）
	var roll = result.result
	result_label.text = "[color=#c0a060]══════ 掷骰结果 ══════[/color]\n"
	result_label.text += "掷骰：2d6 = [color=#ffcc00]?[/color]\n"
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(func():
		result_label.text = "[color=#c0a060]══════ 掷骰结果 ══════[/color]\n"
		result_label.text += "掷骰：2d6 = %d | 属性加值：%d | 最终：%d\n" % [roll.roll_value, roll.attr_bonus, roll.final_value]
	)
	tw.tween_interval(0.3)
	tw.tween_callback(func():
		result_label.text += "[color=#ffcc00]%s[/color]" % roll.tier_name
		result_label.text += result.description
		result_label.text += _effects_text(result.effects)
		# 轻动效：结果"落定"时微微一顿（骰子定音）
		result_label.pivot_offset = result_label.size / 2.0
		result_label.scale = Vector2(0.98, 0.98)
		var pop := create_tween()
		pop.tween_property(result_label, "scale", Vector2.ONE, VisualConfig.TWEEN_POPUP_IN)
		_show_close()
	)

func _on_close() -> void:
	queue_free()

# ============================================================
# 直接显示行动结果（无选择，纯展示骰子+效果）
# ============================================================
func show_action_result(action_title: String, body_text: String, dice_result: Dictionary, effects: Array) -> void:
	_resolved = true
	title_label.text = action_title
	text_label.text = body_text

	# 隐藏选择按钮区域
	for child in choices_container.get_children():
		child.queue_free()
	choices_container.visible = false

	# 骰子结果
	var roll = dice_result
	result_label.text = "[color=#c0a060]══════ 掷骰结果 ══════[/color]\n"
	result_label.text += "掷骰：2d6 = %d | 属性加值：%+d | 最终：%d\n" % [roll.get("roll_value", 0), roll.get("attr_bonus", 0), roll.get("final_value", 0)]
	result_label.text += "[color=#ffcc00]%s[/color]" % roll.get("tier_name", "")
	result_label.text += _effects_text(effects)

	# 轻动效：结果淡入 + 微缩放落定
	result_label.modulate.a = 0.0
	result_label.pivot_offset = result_label.size / 2.0
	result_label.scale = Vector2(0.98, 0.98)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(result_label, "modulate:a", 1.0, VisualConfig.TWEEN_POPUP_IN)
	tw.tween_property(result_label, "scale", Vector2.ONE, VisualConfig.TWEEN_POPUP_IN)
	_show_close()

# ============================================================
# 效果列表文本（事件选择 / 行动结果共用）
# ============================================================
func _effects_text(effects: Array) -> String:
	var out := ""
	if not effects.is_empty():
		out += "\n[color=#80ff80]效果：[/color]\n"
		for eff in effects:
			var type = eff.get("type", "")
			var value = eff.get("value", 0)
			if type == "skill":
				out += "\n  · %s Lv%d" % [eff.get("name", ""), value]
			elif value > 0:
				out += "\n  · %s +%d" % [type, value]
			elif value < 0:
				out += "\n  · %s %d" % [type, value]
	return out

# ============================================================
# 关闭按钮淡入（操作反馈：结果呈现后才出现「关闭」）
# ============================================================
func _show_close() -> void:
	close_button.visible = true
	close_button.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(close_button, "modulate:a", 1.0, VisualConfig.TWEEN_POPUP_IN)

# ============================================================
# 操作反馈：青铜按钮样式 + 悬停/按下轻动效
# ============================================================
func _style_feedback_button(btn: Button) -> void:
	var styles := VisualConfig.make_button_stylebox()
	btn.add_theme_stylebox_override("normal", styles["normal"])
	btn.add_theme_stylebox_override("hover", styles["hover"])
	btn.add_theme_stylebox_override("pressed", styles["pressed"])

	# 禁用态：压暗铜绿，避免与可选态混淆
	var disabled := styles["normal"].duplicate() as StyleBoxFlat
	disabled.bg_color = VisualConfig.BG_MID_BROWN
	disabled.border_color = Color(VisualConfig.BRONZE, 0.4)
	btn.add_theme_stylebox_override("disabled", disabled)

	# 缩放锚点跟随控件尺寸（容器布局完成后仍居中缩放）
	btn.pivot_offset = btn.size / 2.0
	btn.resized.connect(func(): btn.pivot_offset = btn.size / 2.0)

	# 悬停/按下轻动效
	btn.mouse_entered.connect(func():
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.03, 1.03), VisualConfig.TWEEN_HOVER)
	)
	btn.mouse_exited.connect(func():
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, VisualConfig.TWEEN_HOVER)
	)
	btn.button_down.connect(func():
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(0.97, 0.97), VisualConfig.TWEEN_PRESS)
	)
	btn.button_up.connect(func():
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2.ONE, VisualConfig.TWEEN_PRESS)
	)
