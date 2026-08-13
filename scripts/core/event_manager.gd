# EventManager.gd — 事件管理器（Autoload）
# 加载事件JSON、条件判断、骰子解析、效果执行
extends Node

# ============================================================
# 信号
# ============================================================
signal event_ready(event_data: Dictionary)
signal event_resolved(event_id: String, result: Dictionary)

# ============================================================
# 数据
# ============================================================
var _event_pool: Array = []           # 当前可用的事件池
var _current_event: Dictionary = {}   # 当前激活的事件
var _random_event_queue: Array = []   # 随机事件队列
var _event_cooldowns: Dictionary = {} # 事件冷却追踪

# ============================================================
# 事件加载
# ============================================================
func _ready() -> void:
	load_events()

func load_events() -> void:
	var file = FileAccess.open("res://resources/events/西周/events.json", FileAccess.READ)
	if file:
		var text = file.get_as_text()
		var json = JSON.parse_string(text)
		if json:
			_event_pool = json.get("events", [])
			print("[EventManager] 已加载 %d 个事件" % _event_pool.size())
		file.close()
	else:
		push_warning("[EventManager] 未找到事件文件，使用内置事件")
		_create_builtin_events()

func _create_builtin_events() -> void:
	# 创建一些内置的兜底事件
	_event_pool = [
		{
			"id": "random_encounter",
			"type": "random",
			"title": "市井偶遇",
			"text": "你在镐京的街市上闲逛，一位衣着朴素但器宇不凡的老者向你搭话。",
			"illustration": "res://resources/textures/events/event_court_audience.png",
			"trigger_weight": {"base": 8},
			"prerequisites": [],
			"choices": [
				{
					"text": "恭敬行礼，请教老者",
					"resolution": {"dice": "2d6", "attr": "cha", "outcomes": {
						"critical": "老者原来是一位隐居的智者——他传授了你一套珍贵的礼法心得。",
						"success": "老者对你的态度很满意，指点了几句。",
						"partial": "老者只是敷衍了几句便离开了。",
						"failure": "老者冷哼一声：'孺子不可教也。'"
					}},
					"effects": {
						"critical": "reputation+5, skill_礼法:1",
						"success": "reputation+2",
						"partial": "",
						"failure": "reputation-1"
					}
				},
				{
					"text": "不理不睬，继续前行",
					"resolution": {"dice": "2d6", "attr": "luk", "outcomes": {
						"critical": "你错过老者后，却在转角处捡到了一枚玉佩。",
						"success": "什么都没发生，平淡的一天。",
						"partial": "你回头时，老者已经不见了踪影。",
						"failure": "路人窃窃私语：'这人好生无礼。'"
					}},
					"effects": {
						"critical": "wealth+30",
						"success": "",
						"partial": "",
						"failure": "reputation-1"
					}
				}
			]
		}
	]

# ============================================================
# 事件触发
# ============================================================
func check_and_trigger() -> Dictionary:
	if _event_pool.is_empty():
		_create_builtin_events()

	# 检查冷却——同一事件不会在短时间内重复触发
	var available_events = []
	for event in _event_pool:
		var event_id = event.get("id", "")
		var last_triggered = _event_cooldowns.get(event_id, -999)
		if GameState.current_year - last_triggered >= 1:
			if _check_prerequisites(event):
				available_events.append(event)

	if available_events.is_empty():
		return {}

	# 加权随机选择
	var selected = DiceSystem.weighted_random_select(available_events, "trigger_weight.base")
	if selected.is_empty():
		return {}

	# 设置冷却
	_event_cooldowns[selected.get("id", "")] = GameState.current_year
	_current_event = selected

	event_ready.emit(selected)
	return selected

func trigger_specific_event(event_id: String) -> Dictionary:
	for event in _event_pool:
		if event.get("id") == event_id:
			if _check_prerequisites(event):
				_current_event = event
				event_ready.emit(event)
				return event
	return {}

# ============================================================
# 前置条件检查
# ============================================================
func _check_prerequisites(event: Dictionary) -> bool:
	var prereqs = event.get("prerequisites", [])
	if prereqs.is_empty():
		return true

	var char = GameState.current_character
	for prereq in prereqs:
		var type = prereq.get("type", "")
		match type:
			"min_attribute":
				var val = char.get("attributes", {}).get(prereq.get("attr", ""), 0)
				if val < prereq.get("value", 0):
					return false
			"min_reputation":
				if char.reputation < prereq.get("value", 0):
					return false
			"social_class":
				if char.social_class != prereq.get("value", ""):
					return false
			"min_age":
				if CharacterManager.get_character_age(char) < prereq.get("value", 0):
					return false
	return true

# ============================================================
# 骰子解析事件选择
# ============================================================
func resolve_choice(choice_index: int) -> Dictionary:
	if _current_event.is_empty():
		return {"error": "没有活跃的事件"}

	var choices = _current_event.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return {"error": "无效的选择索引"}

	var choice = choices[choice_index]
	var resolution = choice.get("resolution", {})
	var dice_formula = resolution.get("dice", "2d6")
	var attr_key = resolution.get("attr", "luk")

	var char = GameState.current_character
	var attr_value = char.get("attributes", {}).get(attr_key, 10)
	var attr_bonus = DiceSystem.attr_to_bonus(attr_value)
	var luck_mod = char.get("attributes", {}).get("luk", 10) / 5 - 2  # -1到+2

	var result = DiceSystem.roll_dice(dice_formula, attr_bonus, luck_mod)
	var tier_key = _tier_to_key(result.tier)

	# 获取结果描述和效果
	var outcomes = resolution.get("outcomes", {})
	var description = outcomes.get(tier_key, "事情就这样发生了。")
	var effects_str = choice.get("effects", {}).get(tier_key, "")

	# 应用效果
	var applied_effects = _apply_effects(effects_str)

	# 记录
	GameState.log_event(_current_event.get("id", ""), choice_index, result.tier_name, applied_effects)

	# 清除当前事件
	var event_done = _current_event.duplicate()
	_current_event = {}

	event_resolved.emit(event_done.get("id", ""), {
		"choice": choice_index,
		"result": result,
		"description": description,
		"effects": applied_effects
	})

	return {
		"event_title": event_done.get("title", ""),
		"choice_text": choice.get("text", ""),
		"description": description,
		"result": result,
		"effects": applied_effects,
		"tier_name": result.tier_name
	}

func _tier_to_key(tier: int) -> String:
	match tier:
		0: return "critical"
		1: return "success"
		2: return "partial"
		3: return "failure"
	return "partial"

# ============================================================
# 效果解析和应用
# ============================================================
func _apply_effects(effects_str: String) -> Array:
	var applied: Array = []
	if effects_str.is_empty():
		return applied

	var parts = effects_str.split(",", false)
	var char = GameState.current_character

	for part in parts:
		part = part.strip_edges()
		if part.is_empty():
			continue

		# 解析 "reputation+5" 或 "wealth-10" 或 "skill_礼法:1"
		if part.begins_with("skill_"):
			var skill_part = part.substr(6)  # "礼法:1"
			var skill_parts = skill_part.split(":")
			if skill_parts.size() == 2:
				CharacterManager.add_skill(char, skill_parts[0], int(skill_parts[1]))
				applied.append({"type": "skill", "name": skill_parts[0], "value": int(skill_parts[1])})
			continue

		# 找最后一个 +/- 之后跟数字
		for op_char in ["+", "-"]:
			var idx = part.find_last(op_char)
			if idx > 0:
				var attr = part.substr(0, idx)
				var value_str = part.substr(idx + 1)
				if value_str.is_valid_int():
					var value = int(value_str)
					if op_char == "-":
						value = -value

					match attr:
						"reputation":
							CharacterManager.modify_reputation(char, value)
						"wealth":
							CharacterManager.modify_wealth(value)
						"health":
							CharacterManager.modify_health(char, value)
						"ambition":
							CharacterManager.modify_ambition(char, value)
						_:
							push_warning("未知效果属性: %s" % attr)

					applied.append({"type": attr, "value": value})
					break

	return applied

# ============================================================
# 条件查询
# ============================================================
func has_active_event() -> bool:
	return not _current_event.is_empty()

func get_current_event() -> Dictionary:
	return _current_event

func get_current_event_choices() -> Array:
	return _current_event.get("choices", [])
