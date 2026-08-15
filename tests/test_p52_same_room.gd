extends Node
# P5-2 同房交互专项测试：四档亲密副作用 / 冷却防重复 / 已孕求子禁用 / 安胎入口
# 用法：godot --headless --path . res://tests/test_p52_same_room.tscn

func _ready() -> void:
	var fails: Array[String] = []

	var char: Dictionary = CharacterManager.create_character({
		"name": "昌", "surname": "姬", "clan": "周", "age": 25,
		"profession": "小吏", "social_level": 1,
		"attr_bonus": {"con": 4, "int": 4, "luk": 6},
	})
	GameState.current_character = char
	GameState.family_data["family_tree"] = {}
	GameState.family_data["wealth"] = 500
	GameState.household_data["wealth"] = 100
	GameState.current_year = -1046
	GameState.last_births = []

	var marry = CharacterManager.propose_marriage(char, "姜", "齐", 30)
	if not marry.get("success", false):
		fails.append("娶妻失败：%s" % marry.get("message", ""))
	else:
		var game = load("res://scenes/game.tscn").instantiate()
		add_child(game)
		for i in range(5):
			await get_tree().process_frame

		var wife: Dictionary = char.relationships.spouse
		wife["is_pregnant"] = false
		wife["intimacy"] = 50
		wife["health"] = 80

		# 1. 同房四档副作用：无论哪档，亲密必增（≥+1）
		game._do_try_for_baby("wife", 0)
		await get_tree().process_frame
		var int1 = wife.get("intimacy", 0)
		if int1 <= 50:
			fails.append("同房后亲密应增长（当前 %d）" % int1)

		# 2. 冷却防重复：本季再次同房应被拦截，亲密不变
		game._do_try_for_baby("wife", 0)
		await get_tree().process_frame
		var int2 = wife.get("intimacy", 0)
		if int2 != int1:
			fails.append("同房冷却失效：第二次同房亲密仍变（%d → %d）" % [int1, int2])

		# 3. 已孕求子禁用：_get_family_actions 中求子应 disabled
		wife["is_pregnant"] = true
		var sp_actions = game._get_family_actions("spouse", wife)
		var find_baby_disabled = false
		var has_an_tai = false
		for a in sp_actions:
			if a.text.begins_with("🌙 求子"):
				find_baby_disabled = a.get("disabled", false)
			if a.text.begins_with("🧘 安胎"):
				has_an_tai = true
		if not find_baby_disabled:
			fails.append("妻已孕时求子按钮应禁用")
		if not has_an_tai:
			fails.append("妻已孕时家族面板应有安胎入口")

		# 4. 安胎入口：扣 10 石 + 标记 an_tai
		GameState.household_data["wealth"] = 100
		game._do_settle_womb("wife", 0)
		await get_tree().process_frame
		if not wife.get("an_tai", false):
			fails.append("安胎后应标记 an_tai=true")
		elif GameState.household_data.get("wealth", 0) != 90:
			fails.append("安胎应扣 10 石，实际剩 %d" % GameState.household_data.get("wealth", 0))

		# 5. 妾室按人冷却：两位妾各有独立 try_baby 冷却 ID
		var cn1 = {"name": "甲妾", "surname": "姚", "gender": "female", "birth_year": -1030,
			"attributes": {"con": 6, "int": 6, "str": 5, "cha": 7, "vir": 5, "luk": 5}, "loyalty": 60, "is_pregnant": false}
		var cn2 = {"name": "乙妾", "surname": "妫", "gender": "female", "birth_year": -1032,
			"attributes": {"con": 6, "int": 6, "str": 5, "cha": 7, "vir": 5, "luk": 5}, "loyalty": 60, "is_pregnant": false}
		GameState.family_data["concubines"] = [cn1, cn2]
		var cn1_actions = game._get_family_actions("concubine", cn1)
		var cn2_actions = game._get_family_actions("concubine", cn2)
		var cn1_cd = ""
		var cn2_cd = ""
		for a in cn1_actions:
			if a.text.begins_with("🌙 求子"):
				cn1_cd = a.get("cooldown", "")
		for a in cn2_actions:
			if a.text.begins_with("🌙 求子"):
				cn2_cd = a.get("cooldown", "")
		if cn1_cd == cn2_cd or cn1_cd == "" or cn2_cd == "":
			fails.append("两位妾求子冷却 ID 应各不相同（%s / %s）" % [cn1_cd, cn2_cd])

	if fails.is_empty():
		print("✅ P5-2 同房交互测试通过：四档亲密/冷却防重复/已孕禁用/安胎/成员级冷却")
	else:
		print("❌ P5-2 同房交互测试失败：")
		for f in fails:
			print("  - " + f)
	get_tree().quit(0 if fails.is_empty() else 1)
