extends Node
# P5-1 生育深度专项测试：受孕年龄修正 / 子女软上限 / 孕期推进 / 分娩通路 / 安胎
# 用法：godot --headless --path . res://tests/test_p51_fertility.tscn

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
	GameState.current_year = -1046
	GameState.last_births = []

	# 1. 受孕年龄修正：55岁+体弱妾，受孕率被压到低位
	var concubines: Array = [{
		"name": "旧妾", "gender": "female", "birth_year": GameState.current_year - 55,
		"attributes": {"con": 6, "int": 6, "str": 5, "cha": 7, "vir": 5, "luk": 5},
		"health": 30, "loyalty": 60, "is_pregnant": false,
	}]
	GameState.family_data["concubines"] = concubines
	var old_r = CharacterManager.start_pregnancy("concubine", 0)
	if old_r.get("fertility", 999) > 5.0:
		fails.append("高龄体弱妾受孕率应被压低到 ≤5%，实际 %.1f%%" % old_r.get("fertility", 999))

	# 2. 子女软上限：≥20 子，受孕率封顶 0（确定性）
	var many_children: Array = []
	for ci in range(20):
		many_children.append({"name": "子%d" % ci, "gender": "male", "birth_year": -1020, "mother_type": "wife", "mother_index": 0})
	char.relationships.children = many_children
	var cap_r = CharacterManager.start_pregnancy("concubine", 0)
	if cap_r.get("fertility", -1) != 0.0:
		fails.append("子嗣≥20 受孕率应为 0，实际 %.1f" % cap_r.get("fertility", -1))
	char.relationships.children = []
	concubines[0]["birth_year"] = GameState.current_year - 20
	concubines[0]["health"] = 80

	# 3. 娶妻
	var marry = CharacterManager.propose_marriage(char, "姜", "齐", 30)
	if not marry.get("success", false):
		fails.append("娶妻失败：%s" % marry.get("message", ""))
	else:
		var wife: Dictionary = char.relationships.spouse
		# 3b. 孕期推进：remaining 2 → 1，不分娩
		wife["is_pregnant"] = true
		wife["pregnancy_remaining"] = 2
		GameState.last_births = []
		var before_children = char.relationships.get("children", []).size()
		CharacterManager.process_pregnancies(char)
		if wife.get("pregnancy_remaining", -1) != 1:
			fails.append("孕期推进失败：remaining 应为 1，实际 %d" % wife.get("pregnancy_remaining", -1))
		if char.relationships.get("children", []).size() != before_children:
			fails.append("remaining=2 不应分娩")
		if not GameState.last_births.is_empty():
			fails.append("remaining=2 不应有分娩弹窗数据")

		# 3c. 分娩通路：remaining 1 → 分娩，产后处理
		wife["pregnancy_remaining"] = 1
		wife["health"] = 80
		GameState.last_births = []
		var children_before = char.relationships.get("children", []).size()
		CharacterManager.process_pregnancies(char)
		if wife.get("is_pregnant", true):
			fails.append("分娩后 is_pregnant 应复位为 false")
		if wife.get("birth_count", 0) != 1:
			fails.append("分娩后 birth_count 应为 1，实际 %d" % wife.get("birth_count", 0))
		if wife.get("health", 80) > 65:
			fails.append("产后 health 应至少 -15，实际 %d" % wife.get("health", 80))
		if wife.get("an_tai", true):
			fails.append("产后 an_tai 应复位为 false")
		if GameState.last_births.is_empty():
			fails.append("分娩应产生弹窗数据")
		var has_live_child = false
		for br in GameState.last_births:
			var c = br.get("child")
			if c is Dictionary and not c.is_empty():
				has_live_child = true
				var in_children = false
				for cc in char.relationships.get("children", []):
					if cc == c:
						in_children = true
				if not in_children:
					fails.append("新生儿未写入 relationships.children")
				var in_tree = false
				for tt in GameState.family_data.family_tree.get("children", []):
					if tt == c:
						in_tree = true
				if not in_tree:
					fails.append("新生儿未写入家族树")
				if not c.has("is_incest"):
					fails.append("新生儿缺少 is_incest 字段")
				if c.has("premature") and c.get("attributes", {}).get("con", 10) > 15:
					fails.append("早产儿体质不应过高")
		# 分娩数量应至少 1 个孩子记录（多胞胎也可能）
		if not has_live_child and not GameState.last_births.is_empty():
			var only_still = true
			for br in GameState.last_births:
				if br.get("outcome") != "stillbirth":
					only_still = false
			if only_still:
				fails.append("死胎路径：婴儿未入 children，但 birth_count/health/last_births 需正常（本处仅检查结构）")

		# 4. 安胎：花钱降险
		wife["is_pregnant"] = true
		wife["pregnancy_remaining"] = 3
		wife["an_tai"] = false
		var wealth_before = GameState.household_data.get("wealth", 0)
		GameState.household_data["wealth"] = 100
		var womb = CharacterManager.settle_womb(char, "wife", 0)
		if not womb.get("ok", false):
			fails.append("安胎应成功：%s" % womb.get("msg", ""))
		elif not wife.get("an_tai", false):
			fails.append("安胎后应标记 an_tai=true")
		elif GameState.household_data.get("wealth", 0) != 90:
			fails.append("安胎应扣 10 石，实际剩 %d" % GameState.household_data.get("wealth", 0))
		# 重复安胎应拒绝
		var womb2 = CharacterManager.settle_womb(char, "wife", 0)
		if womb2.get("ok", true):
			fails.append("重复安胎应被拒绝")
		# 未孕安胎应拒绝
		wife["is_pregnant"] = false
		wife["an_tai"] = false
		var womb3 = CharacterManager.settle_womb(char, "wife", 0)
		if womb3.get("ok", true):
			fails.append("未孕安胎应被拒绝")

	if fails.is_empty():
		print("✅ P5-1 生育深度测试通过：受孕年龄/软上限/孕期推进/分娩通路/安胎")
	else:
		print("❌ P5-1 生育深度测试失败：")
		for f in fails:
			print("  - " + f)
	get_tree().quit(0 if fails.is_empty() else 1)
