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
var _event_cooldowns: Dictionary = {} # 事件冷却追踪（防重复触发由冷却+季节双重控制）

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

	# 季节联动：读取当前季节（春/夏/秋/冬），事件可在 JSON 声明 seasons 限定季节
	var season_name = _season_name()

	# 候选事件：冷却通过 + 前置条件 + 季节匹配，同时计算当季权重
	var weighted_events: Array = []
	var has_seasonal := false  # 本季是否存在季节专属候选
	for event in _event_pool:
		var event_id = event.get("id", "")
		var last_triggered = _event_cooldowns.get(event_id, -999)
		# 冷却——同一事件不会在短时间内重复触发
		if GameState.current_year - last_triggered < 1:
			continue
		# once-ever 守卫：已完成的历史事件不再触发
		if event.get("once", false) and GameState.completed_timeline_events.has(event_id):
			continue
		if not _check_prerequisites(event):
			continue
		# 季节限定：声明了 seasons 的事件仅在对应季节出现
		var seasons = event.get("seasons", [])
		var is_seasonal: bool = seasons is Array and not seasons.is_empty()
		if is_seasonal and not seasons.has(season_name):
			continue
		if is_seasonal:
			has_seasonal = true
		var weight = _event_weight(event, is_seasonal, season_name)
		if weight > 0:
			weighted_events.append({"event": event, "weight": weight, "seasonal": is_seasonal})

	if weighted_events.is_empty():
		return {}

	# 当季有季节专属事件时，压低通用事件权重，让"当季特色"更容易浮现
	if has_seasonal:
		for entry in weighted_events:
			if not entry.get("seasonal", false):
				entry["weight"] = float(entry["weight"]) * GENERIC_SEASON_SUPPRESS

	# 加权随机选择（本地实现，正确读取 trigger_weight.base）
	var selected = _weighted_pick(weighted_events)
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
# 季节联动 + 加权随机抽取
# ============================================================
# 季节限定事件在当季的权重加成倍数（事件可用 trigger_weight.season_boost 覆盖）
const SEASON_BOOST_DEFAULT := 1.5

# 当季存在季节专属事件时，通用（非季节）事件的权重压低系数，让季节特色更明显
const GENERIC_SEASON_SUPPRESS := 0.6

# 当前季节中文名（复用 TimeManager.get_season_name：春/夏/秋/冬）。
# 事件 JSON 可声明 "seasons": ["春","秋"] 限定只在对应季节出现；
# 不声明 seasons 的事件四季通用（向后兼容）。
func _season_name() -> String:
	if TimeManager and TimeManager.has_method("get_season_name"):
		return TimeManager.get_season_name()
	return "春"  # 兜底：TimeManager 缺失时按春季处理

# 计算事件当季权重：基础权重 trigger_weight.base（缺省 1.0），
# 季节限定事件再乘加成：优先取 trigger_weight.当季名键（如 "春": 2.0），
# 其次 trigger_weight.season_boost，最后回落 SEASON_BOOST_DEFAULT。
func _event_weight(event: Dictionary, is_seasonal: bool, season_name: String) -> float:
	var tw: Dictionary = event.get("trigger_weight", {})
	var weight = float(tw.get("base", 1.0))
	if is_seasonal:
		weight *= float(tw.get(season_name, tw.get("season_boost", SEASON_BOOST_DEFAULT)))
	return weight

# 按权重随机抽取。本地实现原因：DiceSystem.weighted_random_select 用 item.get(weight_key)
# 只能读顶层键，读不到嵌套的 trigger_weight.base（会全部退化为权重 1.0，等价均匀随机）。
func _weighted_pick(weighted: Array) -> Dictionary:
	var total: float = 0.0
	for entry in weighted:
		total += float(entry.get("weight", 0.0))
	if total <= 0:
		return {}
	var roll = randf() * total
	var cumulative: float = 0.0
	for entry in weighted:
		cumulative += float(entry.get("weight", 0.0))
		if roll <= cumulative:
			return entry.get("event", {})
	return weighted.back().get("event", {})

# ============================================================
# 前置条件检查
# ============================================================
func _check_single_condition(cond: Dictionary) -> bool:
	"""单条前置条件判断（事件前置 + 条件式结局共用；未知类型静默放行）"""
	var char = GameState.current_character
	match cond.get("type", ""):
		"min_attribute":
			return char.get("attributes", {}).get(cond.get("attr", ""), 0) >= cond.get("value", 0)
		"min_reputation":
			return char.reputation >= cond.get("value", 0)
		"social_class":
			return char.social_class == cond.get("value", "")
		"min_age":
			return CharacterManager.get_character_age(char) >= cond.get("value", 0)
		"min_year":
			return GameState.current_year >= cond.get("value", 0)
		"max_year":
			return GameState.current_year <= cond.get("value", 0)
		"year_range":
			var rg = cond.get("value", [])
			return rg.size() == 2 and GameState.current_year >= rg[0] and GameState.current_year <= rg[1]
		"min_power":
			return char.derived.get("power", 0) >= cond.get("value", 0)
		"min_king_favor":
			return char.get("king_favor", 0) >= cond.get("value", 0)
		"min_military_merit":
			return char.get("military_merit", 0) >= cond.get("value", 0)
		"min_skill":
			var sk_val := 0
			for sk in char.get("skills", []):
				if String(sk).begins_with(cond.get("skill", "") + ":"):
					sk_val = maxi(sk_val, int(String(sk).split(":")[1]))
			return sk_val >= cond.get("value", 0)
		"has_official_position":
			return not char.get("official_position", "").is_empty()
		"social_level":
			return char.social_level >= cond.get("value", 0)
	return true

func _check_prerequisites(event: Dictionary) -> bool:
	var prereqs = event.get("prerequisites", [])
	if prereqs.is_empty():
		return true
	for prereq in prereqs:
		if not _check_single_condition(prereq):
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

	# 气运点（P2-6）：天命所归——首掷非大成功/成功且气运≥15时，自动重掷一次、消耗2气运。
	# 复用 DiceSystem.roll_with_fate，不改事件流（resolve_choice 只调一次）。
	var luk_val: int = char.get("attributes", {}).get("luk", 10)
	var fate = DiceSystem.roll_with_fate(luk_val, dice_formula, attr_bonus, luck_mod)
	var result = fate.get("result", {})
	if fate.get("rerolled", false):
		CharacterManager.modify_attribute(char, "luk", -int(fate.get("fate_cost", 2)))
		result["fate_rerolled"] = true
	var tier_key = _tier_to_key(result.tier)

	# 获取结果描述和效果
	var outcomes = resolution.get("outcomes", {})
	var description = outcomes.get(tier_key, "事情就这样发生了。")
	# 条件式结局：outcome 可为 {text, condition, refused}，条件不满足则显示拒绝文案
	if description is Dictionary:
		var cond_ok := true
		for cd in description.get("condition", []):
			if not _check_single_condition(cd):
				cond_ok = false
				break
		if cond_ok:
			description = description.get("text", "事情就这样发生了。")
		else:
			description = description.get("refused", "你声望尚不足以如此。")
	var effects_str = choice.get("effects", {}).get(tier_key, "")

	# 应用效果
	var applied_effects = _apply_effects(effects_str)

	# 记录
	GameState.log_event(_current_event.get("id", ""), choice_index, result.tier_name, applied_effects)

	# 清除当前事件
	var event_done = _current_event.duplicate()
	_current_event = {}
	# once-ever 守卫：once 事件解析后标记完成，不再重复触发
	if event_done.get("once", false) and not GameState.completed_timeline_events.has(event_done.get("id", "")):
		GameState.completed_timeline_events.append(event_done.get("id", ""))

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

		# 赐/夺封地（无 +/- 数字的特殊效果）
		if part.begins_with("fief_set:"):
			var place = part.substr(9).strip_edges()
			if not place.is_empty():
				var c0 = GameState.current_character
				c0["fief"] = place
				applied.append({"type": "fief_set", "value": place})
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
						"con", "int", "str", "cha", "vir", "luk":
							# 六维属性成长——事件 JSON 可驱动天资增减（此前会 push_warning 静默失败）
							CharacterManager.modify_attribute(char, attr, value)
						"king_favor":
							CharacterManager.modify_king_favor(char, value)
						"military_merit":
							CharacterManager.modify_military_merit(char, value)
						"regency_power":
							CharacterManager.modify_regency_power(char, value)
						"noble":
							CharacterManager.advance_noble_title(char)
						"promote":
							CharacterManager.grant_promotion(char)
						"demote":
							CharacterManager.demote_character(char, maxi(1, value))
						"social_level":
							char.social_level = clampi(value, 1, 6)
							char.social_class = CharacterManager.SOCIAL_CLASSES[char.social_level].name
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
