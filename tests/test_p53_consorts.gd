extends Node
# P5-3 妻妾交互专项测试：无子女也显示妾室 / 夫人媵通补考察安抚 / 成员级冷却 / 正妻死亡让位再娶 / 侧室老化死亡
# 用法：godot --headless --path . res://tests/test_p53_consorts.tscn

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

	var marry = CharacterManager.propose_marriage(char, "姜", "齐", 30)
	if not marry.get("success", false):
		fails.append("娶妻失败：%s" % marry.get("message", ""))
	else:
		var game = load("res://scenes/game.tscn").instantiate()
		add_child(game)
		for i in range(5):
			await get_tree().process_frame

		var mk_consort := func(n, sur, byr):
			return {"name": n, "surname": sur, "gender": "female", "birth_year": byr,
				"attributes": {"con": 6, "int": 6, "str": 5, "cha": 7, "vir": 5, "luk": 5}, "loyalty": 60, "is_pregnant": false}
		# 无子女，纯妾室/夫人/媵/通房
		var cn = mk_consort.call("甲妾", "姚", -1030)
		var cn2 = mk_consort.call("乙妾", "妫", -1032)
		var fr1 = mk_consort.call("贵夫人", "姒", -1034)
		var fr2 = mk_consort.call("次夫人", "子", -1036)
		var yq = mk_consort.call("媵姬", "姜", -1035)
		var tf = mk_consort.call("秀奴", "婢", -1038)
		GameState.family_data["concubines"] = [cn, cn2]
		GameState.family_data["furens"] = [fr1, fr2]
		GameState.family_data["ying_qie"] = [yq]
		GameState.family_data["tongfangs"] = [tf]

		# 1. 无子女也显示妾室（家族面板渲染含"妾:"行）
		game._family_vbox = VBoxContainer.new()
		add_child(game._family_vbox)
		game._build_family_content()
		await get_tree().process_frame
		var found_cn_label = false
		for child in game._family_vbox.get_children():
			if child is Button and child.text.begins_with("妾:"):
				found_cn_label = true
		if not found_cn_label:
			fails.append("无子女时家族面板未显示妾室行")
		game._family_vbox.queue_free()

		# 2. 夫人/媵妾/通房补考察忠诚/安抚按钮
		for pair in [["furen", fr1], ["ying_qie", yq], ["tongfang", tf]]:
			var rt: String = pair[0]
			var md: Dictionary = pair[1]
			var acts = game._get_family_actions(rt, md)
			var has_test = false
			var has_boost = false
			var has_bond = false
			for a in acts:
				if a.text.begins_with("🔍"):
					has_test = true
				if a.text.begins_with("🎁"):
					has_boost = true
				if a.text.begins_with("❤️"):
					has_bond = true
			if not (has_test and has_boost and has_bond):
				fails.append("%s 缺少考察/安抚/亲近按钮" % rt)

		# 3. 成员级冷却：两名妾 交谈/亲近 冷却 ID 各不同；两名夫人亦然
		var cn1_acts = game._get_family_actions("concubine", cn)
		var cn2_acts = game._get_family_actions("concubine", cn2)
		var cn1_talk = ""; var cn1_bond = ""
		var cn2_talk = ""; var cn2_bond = ""
		for a in cn1_acts:
			if a.text.begins_with("💬"): cn1_talk = a.get("cooldown", "")
			if a.text.begins_with("❤️"): cn1_bond = a.get("cooldown", "")
		for a in cn2_acts:
			if a.text.begins_with("💬"): cn2_talk = a.get("cooldown", "")
			if a.text.begins_with("❤️"): cn2_bond = a.get("cooldown", "")
		if cn1_talk == cn2_talk or cn1_bond == cn2_bond or cn1_talk == "":
			fails.append("两名妾 交谈/亲近 冷却应按人区分（%s/%s · %s/%s）" % [cn1_talk, cn2_talk, cn1_bond, cn2_bond])
		var fr1_acts = game._get_family_actions("furen", fr1)
		var fr2_acts = game._get_family_actions("furen", fr2)
		var fr1_bond = ""; var fr2_bond = ""
		for a in fr1_acts:
			if a.text.begins_with("❤️"): fr1_bond = a.get("cooldown", "")
		for a in fr2_acts:
			if a.text.begins_with("❤️"): fr2_bond = a.get("cooldown", "")
		if fr1_bond == fr2_bond or fr1_bond == "":
			fails.append("两名夫人亲近冷却应各不同（%s/%s）" % [fr1_bond, fr2_bond])

		# 4. 正妻死亡让位再娶（老化循环直至触发）
		var spouse: Dictionary = char.relationships.spouse
		spouse["birth_year"] = GameState.current_year - 60
		spouse["is_alive"] = true
		fr1["birth_year"] = GameState.current_year - 60
		fr1["is_alive"] = true
		var wife_died = false
		var furen_died = false
		for attempt in range(300):
			var r = CharacterManager.update_parents_aging()
			for n in r.get("notices", []):
				if n.find("配偶") >= 0:
					wife_died = true
				if n.find("夫人") >= 0:
					furen_died = true
			if char.relationships.get("spouse", {}).is_empty():
				break
		if not char.relationships.get("spouse", {}).is_empty() or not wife_died:
			fails.append("正妻老死后应清空配偶位（可再娶）")
		# 侧室老化死亡：fr1 高龄应逐渐死亡（若首循环已亡则已捕获；否则续推老化直至其亡）
		if fr1.get("is_alive", true):
			for attempt in range(300):
				var r = CharacterManager.update_parents_aging()
				for n in r.get("notices", []):
					if n.find("夫人") >= 0:
						furen_died = true
				if not fr1.get("is_alive", true):
					break
		if not furen_died:
			fails.append("高龄夫人未老化死亡")

	if fails.is_empty():
		print("✅ P5-3 妻妾交互测试通过：无子女妾室/考察安抚/成员级冷却/正妻死亡/侧室老化")
	else:
		print("❌ P5-3 妻妾交互测试失败：")
		for f in fails:
			print("  - " + f)
	get_tree().quit(0 if fails.is_empty() else 1)
