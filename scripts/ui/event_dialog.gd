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
		var idx = i
		btn.pressed.connect(_on_choice_made.bind(idx))
		choices_container.add_child(btn)

func _on_choice_made(choice_index: int) -> void:
	if _resolved:
		return
	_resolved = true

	# 禁用所有选择按钮
	for child in choices_container.get_children():
		if child is Button:
			child.disabled = true

	# 解析骰子
	var result = EventManager.resolve_choice(choice_index)
	if result.has("error"):
		result_label.text = "错误：%s" % result.error
		close_button.visible = true
		return

	# 显示结果
	var roll = result.result
	result_label.text = "[color=#c0a060]══════ 掷骰结果 ══════[/color]\n"
	result_label.text += "掷骰：2d6 = %d | 属性加值：%d | 最终：%d\n" % [
		roll.roll_value, roll.attr_bonus, roll.final_value
	]
	result_label.text += "[color=#ffcc00]%s[/color]\n\n" % roll.tier_name
	result_label.text += result.description

	# 显示效果
	if not result.effects.is_empty():
		result_label.text += "\n\n[color=#80ff80]效果：[/color]"
		for eff in result.effects:
			var type = eff.get("type", "")
			var value = eff.get("value", 0)
			if type == "skill":
				result_label.text += "\n  · 习得技能：%s Lv%d" % [eff.get("name", ""), value]
			elif value > 0:
				result_label.text += "\n  · %s +%d" % [type, value]
			elif value < 0:
				result_label.text += "\n  · %s %d" % [type, value]

	close_button.visible = true

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
	result_label.text += "掷骰：2d6 = %d | 属性加值：%+d | 最终：%d\n" % [
		roll.get("roll_value", 0), roll.get("attr_bonus", 0), roll.get("final_value", 0)
	]
	result_label.text += "[color=#ffcc00]%s[/color]" % roll.get("tier_name", "")

	# 效果
	if not effects.is_empty():
		result_label.text += "\n\n[color=#80ff80]效果：[/color]"
		for eff in effects:
			var eff_type = eff.get("type", "")
			var value = eff.get("value", 0)
			if eff_type == "skill":
				result_label.text += "\n  · %s Lv%d" % [eff.get("name", ""), value]
			elif value > 0:
				result_label.text += "\n  · %s +%d" % [eff_type, value]
			elif value < 0:
				result_label.text += "\n  · %s %d" % [eff_type, value]

	close_button.visible = true
