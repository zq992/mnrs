extends Node
# P5 家族机制综合集成测试：成婚(陪嫁通房) + 多妻妾求子 + 乱伦姐姐同期孕期 → 统一分娩通路端到端
# 覆盖：孕期推进/分娩分档/陪嫁通房/乱伦孽种 在同一份 family_data 下协同工作
# 用法：godot --headless --path . res://tests/test_family_mechanics.tscn

func _ready() -> void:
	var fails: Array[String] = []
	var char: Dictionary = CharacterManager.create_character({
		"name": "昌", "surname": "姬", "clan": "周", "age": 25,
		"profession": "小吏", "social_level": 4,
		"attr_bonus": {"con": 6, "int": 4, "luk": 6},
	})
	GameState.current_character = char
	GameState.family_data["family_tree"] = {}
	GameState.family_data["wealth"] = 500
	GameState.family_data["scandal_level"] = 0
	GameState.household_data["harmony"] = 60
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

		# 陪嫁通房已随妻入府
		var tfs: Array = GameState.family_data.get("tongfangs", [])
		if tfs.is_empty():
			fails.append("成婚未生成陪嫁通房")
		var wife = char.relationships.spouse

		# 妾室入府
		var cn := {"name": "甲妾", "surname": "姚", "gender": "female", "birth_year": -1030,
			"attributes": {"con": 6, "int": 6, "str": 5, "cha": 7, "vir": 5, "luk": 5}, "loyalty": 60, "is_pregnant": false}
		GameState.family_data["concubines"] = [cn]

		# 同期全员有孕：妻 + 妾 + 通房 + 乱伦姐姐
		wife["is_pregnant"] = true; wife["pregnancy_remaining"] = 3
		cn["is_pregnant"] = true; cn["pregnancy_remaining"] = 3
		if not tfs.is_empty():
			tfs[0]["is_pregnant"] = true; tfs[0]["pregnancy_remaining"] = 3
		var sis := {"name": "仲姜", "surname": "姚", "gender": "female", "birth_year": -1066, "age": 20, "is_alive": true,
			"personality": "温和", "is_pregnant": true, "pregnancy_remaining": 3, "pregnancy_type": "incest"}
		GameState.family_data["siblings"] = [sis]
		CharacterManager.init_sibling_affection(0)

		# 推进 3 季——统一分娩通路
		for _season in range(3):
			CharacterManager.process_pregnancies(char)

		var children: Array = char.relationships.get("children", [])
		if not wife.get("is_pregnant", true) == false:
			fails.append("妻孕期末清空")
		if not cn.get("is_pregnant", true) == false:
			fails.append("妾孕期末清空")
		if not tfs.is_empty() and tfs[0].get("is_pregnant", true) != false:
			fails.append("通房孕期末清空")
		if children.is_empty():
			fails.append("分娩通路未产出任何子女")
		# 孽种必须存在
		var has_incest_child = false
		for c in children:
			if c.get("is_incest", false):
				has_incest_child = true
		if not has_incest_child:
			fails.append("乱伦姐姐未产下孽种")
		if not sis.get("is_pregnant", true) == false:
			fails.append("姐姐孕期末清空")
		# 分娩结构化数据进 last_births（供 UI 弹窗消费）
		if GameState.last_births.is_empty():
			fails.append("分娩结果未写入 GameState.last_births")
		# 家庭树镜像同步
		var tree_children: Array = GameState.family_data.family_tree.get("children", [])
		if tree_children.size() != children.size():
			fails.append("家族树镜像与子女数不一致（%d vs %d）" % [tree_children.size(), children.size()])

		# 同季分娩后产母记录 birth_count
		if wife.get("birth_count", 0) < 1:
			fails.append("妻未记录 birth_count")

	if fails.is_empty():
		print("✅ P5-6 家族机制综合集成测试通过：多妻妾+陪嫁+乱伦同期分娩通路端到端")
	else:
		print("❌ P5-6 家族机制综合集成测试失败：")
		for f in fails:
			print("  - " + f)
	get_tree().quit(0 if fails.is_empty() else 1)
