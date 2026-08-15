extends Node
# P5-4 娶妻陪嫁通房专项测试：成婚生成陪嫁通房 / 随妻标记 / 自娶通房非陪嫁 / 妻亡留府或遣散
# 用法：godot --headless --path . res://tests/test_p54_dowry.tscn

func _ready() -> void:
	var fails: Array[String] = []
	var char: Dictionary = CharacterManager.create_character({
		"name": "昌", "surname": "姬", "clan": "周", "age": 25,
		"profession": "小吏", "social_level": 4,
		"attr_bonus": {"con": 4, "int": 4, "luk": 6},
	})
	GameState.current_character = char
	GameState.family_data["family_tree"] = {}
	GameState.family_data["wealth"] = 500
	GameState.current_year = -1046
	GameState.last_births = []

	# 1. 自娶：成婚即生成 1-2 名陪嫁通房（is_dowry=true + follows_wife）
	var marry = CharacterManager.propose_marriage(char, "姜", "齐", 30)
	if not marry.get("success", false):
		fails.append("娶妻失败：%s" % marry.get("message", ""))
	else:
		var wife_name = char.relationships.spouse.get("name", "")
		var tfs: Array = GameState.family_data.get("tongfangs", [])
		if tfs.is_empty():
			fails.append("成婚未生成陪嫁通房")
		else:
			var dowry_ok = true
			for tf in tfs:
				if not tf.get("is_dowry", false) or tf.get("follows_wife", "") != wife_name:
					dowry_ok = false
				if tf.get("loyalty", 0) < 60 or tf.get("loyalty", 0) > 75:
					fails.append("陪嫁通房忠诚应 60-75，实际 %d" % tf.get("loyalty", 0))
				if tf.get("health", 0) <= 0:
					fails.append("陪嫁通房应带 health 字段")
			if not dowry_ok:
				fails.append("陪嫁通房缺 is_dowry/follows_wife 标记")

		# 2. 自收通房：非陪嫁
		CharacterManager.take_tongfang(char, "郑", "郑", 20)
		var self_tf = GameState.family_data.get("tongfangs", [])[-1]
		if self_tf.get("is_dowry", true) or self_tf.has("follows_wife"):
			fails.append("自收通房不应带陪嫁标记")

		# 3. 妻亡处置：陪嫁通房随妻 留府(is_dowry=false)/遣散(移除)，非陪嫁不动
		var before: Array = GameState.family_data.get("tongfangs", []).duplicate()
		var non_dowry = null
		for tf in before:
			if not tf.get("is_dowry", false):
				non_dowry = tf
		# 手动补一名陪嫁通房，便于验证处置
		var extra = CharacterManager._create_dowry_tongfang(char, char.relationships.spouse)
		GameState.family_data.get("tongfangs", []).append(extra)
		var notices = CharacterManager._dispose_dowry_tongfangs(char, wife_name)
		if notices.is_empty():
			fails.append("妻亡处置陪嫁通房应有通知")
		var after: Array = GameState.family_data.get("tongfangs", [])
		for tf in after:
			if tf.get("is_dowry", false):
				fails.append("处置后仍留有陪嫁标记通房：%s" % tf.get("name", ""))
		if non_dowry != null and not after.has(non_dowry):
			fails.append("非陪嫁通房不应被处置")

		# 4. 父母之命娶妻同样生成陪嫁通房
		char.relationships.spouse = {}
		GameState.family_data["tongfangs"] = []
		CharacterManager.propose_marriage_parents(char, "姒", "杞")
		var tfs2: Array = GameState.family_data.get("tongfangs", [])
		if tfs2.is_empty():
			fails.append("父母之命成婚未生成陪嫁通房")
		else:
			var wife_name2 = char.relationships.spouse.get("name", "")
			for tf in tfs2:
				if not tf.get("is_dowry", false) or tf.get("follows_wife", "") != wife_name2:
					fails.append("父母之命陪嫁通房缺标记")

	# 5. 低等级（通房名额 0）不送陪嫁通房——受 SPOUSE_LIMITS 约束（审查#5 防绕过等级门槛）
	var low_char: Dictionary = CharacterManager.create_character({
		"name": "黎", "surname": "姬", "clan": "周", "age": 25,
		"profession": "小吏", "social_level": 1,
	})
	GameState.current_character = low_char
	GameState.family_data["wealth"] = 500
	GameState.family_data["tongfangs"] = []
	var low_marry = CharacterManager.propose_marriage(low_char, "姜", "齐", 30)
	if low_marry.get("success", false) and not GameState.family_data.get("tongfangs", []).is_empty():
		fails.append("低等级娶妻不应有陪嫁通房")

	if fails.is_empty():
		print("✅ P5-4 陪嫁通房测试通过：成婚陪嫁/随妻标记/自收非陪嫁/妻亡留府或遣散")
	else:
		print("❌ P5-4 陪嫁通房测试失败：")
		for f in fails:
			print("  - " + f)
	get_tree().quit(0 if fails.is_empty() else 1)
