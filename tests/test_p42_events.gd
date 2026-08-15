extends Node
# P4-2 临时验证：时间线事件窗口/once 守卫/效果落地
# 用法：godot --headless --path . res://tests/test_p42_events.tscn

func _ready() -> void:
	var fails: Array[String] = []
	var char: Dictionary = CharacterManager.create_character({
		"name": "昌", "surname": "姬", "clan": "周", "age": 20,
		"profession": "小吏", "social_level": 1,
		"attr_bonus": {"con": 4, "int": 4, "cha": 5},
	})
	GameState.current_character = char
	GameState.completed_timeline_events = []
	GameState.current_year = -1045

	# 1. 三监之乱：窗口内、无年龄门槛 → 应触发
	var e1 = EventManager.trigger_specific_event("wz_sanjian_rebellion")
	if e1.is_empty():
		fails.append("三监之乱未在 -1045 触发")
	else:
		var r1 = EventManager.resolve_choice(0)
		if r1.is_empty() or r1.has("error"):
			fails.append("三监之乱 resolve_choice 失败: %s" % str(r1))
		if not GameState.completed_timeline_events.has("wz_sanjian_rebellion"):
			fails.append("once 事件未记录完成")

	# 2. 周公还政：窗口外(-1000)不应触发
	GameState.current_year = -1000
	if not EventManager.trigger_specific_event("wz_zhougong_return").is_empty():
		fails.append("周公还政窗口(-1036..-1032)外 -1000 仍触发")

	# 3. 周公还政：窗口内(-1034) + 成年 → 应触发
	GameState.current_year = -1034
	if EventManager.trigger_specific_event("wz_zhougong_return").is_empty():
		fails.append("周公还政在 -1034 未触发（成人满足 min_age 12）")

	# 4. 成康册命：窗口内 → 触发并 resolve 一次（验证 official_position 效果路径不报错）
	GameState.current_year = -1002
	var e5 = EventManager.trigger_specific_event("wz_chengkang_ceming")
	if e5.is_empty():
		fails.append("成康册命在 -1002 未触发")
	else:
		var r5 = EventManager.resolve_choice(0)
		if r5.is_empty() or r5.has("error"):
			fails.append("成康册命 resolve 失败: %s" % str(r5))

	# 5. 国人暴动：窗口内 → 触发
	GameState.current_year = -835
	if EventManager.trigger_specific_event("wz_guoren_baodong").is_empty():
		fails.append("国人暴动在 -835 未触发")

	# 6. 效果解析器确定性断言（find_last→rfind 修复回归验证）
	var before_rep: int = char.reputation
	var before_km: int = char.get("military_merit", 0)
	var before_kk: int = char.get("king_favor", 0)
	EventManager._apply_effects("reputation+7, military_merit+3, king_favor-4, fief_set:鲁")
	if char.reputation != before_rep + 7:
		fails.append("reputation+7 未生效（%d→%d）" % [before_rep, char.reputation])
	if char.get("military_merit", 0) != before_km + 3:
		fails.append("military_merit+3 未生效")
	if char.get("king_favor", 0) != before_kk - 4:
		fails.append("king_favor-4 未生效")
	if char.get("fief", "") != "鲁":
		fails.append("fief_set:鲁 未生效")

	if fails.is_empty():
		print("✅ P4-2 时间线事件测试通过")
	else:
		for f in fails:
			printerr("❌ " + f)
	get_tree().quit(0 if fails.is_empty() else 1)
