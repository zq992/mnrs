extends Node
# P5-5 姐弟乱伦线专项测试：分娩通路 / 主动入口门槛 / 败露惩罚 / 继承权剥夺 / 未成年gate / 掩蔽与远嫁
# 用法：godot --headless --path . res://tests/test_p55_incest.tscn

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
	GameState.family_data["scandal_level"] = 0
	GameState.household_data["harmony"] = 60
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

		var sis_ok := {"name": "仲姜", "surname": "姚", "gender": "female", "birth_year": -1066, "age": 20, "is_alive": true, "personality": "温和"}
		var sis_minor := {"name": "季嬴", "surname": "姚", "gender": "female", "birth_year": -1036, "age": 10, "is_alive": true, "personality": "温和"}
		var bro := {"name": "伯禽", "surname": "姬", "gender": "male", "birth_year": -1070, "age": 24, "is_alive": true, "personality": "沉稳"}
		GameState.family_data["siblings"] = [sis_ok, sis_minor, bro]
		CharacterManager.init_sibling_affection(0)
		CharacterManager.set_sibling_affection(0, 95)
		var wife = char.relationships.spouse

		# 1. 主动入口：成年未婚未孕姐姐 → 有"同房（禁忌）"；已孕/未成年/男性 → 无
		var acts = game._get_family_actions("sibling", sis_ok)
		var has_incest_btn = false
		for a in acts:
			if a.text.begins_with("🌙 同房"):
				has_incest_btn = true
		if not has_incest_btn:
			fails.append("成年未婚姐姐应显示乱伦入口")
		sis_ok["is_pregnant"] = true
		var acts_preg = game._get_family_actions("sibling", sis_ok)
		has_incest_btn = false
		for a in acts_preg:
			if a.text.begins_with("🌙 同房"):
				has_incest_btn = true
		if has_incest_btn:
			fails.append("已孕姐姐不应显示乱伦入口")
		sis_ok["is_pregnant"] = false
		var acts_minor = game._get_family_actions("sibling", sis_minor)
		has_incest_btn = false
		for a in acts_minor:
			if a.text.begins_with("🌙 同房"):
				has_incest_btn = true
		if has_incest_btn:
			fails.append("未成年姐妹不应显示乱伦入口")
		var acts_bro = game._get_family_actions("sibling", bro)
		has_incest_btn = false
		for a in acts_bro:
			if a.text.begins_with("🌙 同房"):
				has_incest_btn = true
		if has_incest_btn:
			fails.append("兄弟不应显示乱伦入口")

		# 2. 未成年 gate 硬拦截
		var minor_res = CharacterManager.handle_incest_pregnancy(char, 1)
		if minor_res.get("pregnant", false) or minor_res.get("message", "").find("未成年") < 0:
			fails.append("未成年姐妹乱伦应被硬拦截")

		# 3. 分娩通路：孕期推进3季 → 孽种出生（is_incest，属性受损，丑闻+2，和睦-10）
		sis_ok["is_pregnant"] = true
		sis_ok["pregnancy_remaining"] = 3
		sis_ok["pregnancy_type"] = "incest"
		var before_scandal: int = GameState.family_data.get("scandal_level", 0)
		var before_harmony: int = GameState.household_data.get("harmony", 60)
		CharacterManager.process_pregnancies(char)
		CharacterManager.process_pregnancies(char)
		CharacterManager.process_pregnancies(char)
		var children: Array = char.relationships.get("children", [])
		var incest_child = null
		for c in children:
			if c.get("is_incest", false):
				incest_child = c
		if incest_child == null:
			fails.append("乱伦孕期未产生孽种")
		else:
			if not sis_ok.get("is_pregnant", true) == false:
				fails.append("分娩后姐姐应清空怀孕状态")
			for key in ["con", "int", "str", "cha", "vir", "luk"]:
				if incest_child.attributes.get(key, 10) > 15:
					fails.append("孽种属性应受损（%s=%d）" % [key, incest_child.attributes[key]])
		var scandal_grew = GameState.family_data.get("scandal_level", 0) > before_scandal
		var harmony_drop = GameState.household_data.get("harmony", 60) < before_harmony
		if not scandal_grew:
			fails.append("孽种出生应丑闻+2")
		if not harmony_drop:
			fails.append("孽种出生应和睦-10")

		# 4. 继承权剥夺：孽种（男，成年）不进继承顺位与嫡庶列表
		var di_child := {"name": "伯禽", "surname": "姬", "gender": "male", "birth_year": -1028, "age": 18, "is_alive": true, "is_incest": false, "mother_type": "wife", "mother_index": 0}
		incest_child["is_alive"] = true
		incest_child["gender"] = "male"
		incest_child["birth_year"] = -1030
		children.append(di_child)
		char.relationships.children = children
		var order = CharacterManager.get_inheritance_order(char)
		for c in order:
			if c.get("is_incest", false):
				fails.append("孽种不应出现在继承顺位")
		var di_shu = CharacterManager.get_di_shu_children(char)
		for c in di_shu["di"] + di_shu["shu"]:
			if c.get("is_incest", false):
				fails.append("孽种不应出现在嫡庶分类")

		# 5. 败露惩罚：直接触发 _expose_incest
		var rep_before: int = char.derived.get("reputation", 0)
		var loyalty_before: int = wife.get("loyalty", 80)
		var sc_before: int = GameState.family_data.get("scandal_level", 0)
		CharacterManager._expose_incest(char, 0)
		if GameState.family_data.get("scandal_level", 0) != sc_before + 3:
			fails.append("败露应丑闻+3")
		if char.derived.get("reputation", 0) >= rep_before:
			fails.append("败露应声望大减（-30）")
		if wife.get("loyalty", 80) >= loyalty_before:
			fails.append("败露应妻忠诚-20")
		if not sis_ok.get("incest_exposed", false):
			fails.append("败露应标记 incest_exposed")

		# 6. 掩人耳目：扣20石 + 风声-5
		sis_ok["incest_rumor"] = 7
		var w_before: int = GameState.family_data.get("wealth", 0)
		var cover = CharacterManager.cover_incest_rumor(char, 0)
		if not cover.get("success", false):
			fails.append("掩人耳目应成功：%s" % cover.get("message", ""))
		elif GameState.family_data.get("wealth", 0) != w_before - 20 or sis_ok.get("incest_rumor", 0) != 2:
			fails.append("掩人耳目应扣20石且风声-5")

		# 7. 远嫁：风声清零 + 已婚 + 移出乱伦名单
		var far = CharacterManager.marry_out_sister(char, 0)
		if not far.get("success", false):
			fails.append("远嫁应成功：%s" % far.get("message", ""))
		elif CharacterManager._sibling_is_married(sis_ok) == false:
			fails.append("远嫁后姐姐应标记已婚")
		if sis_ok.get("incest_rumor", 0) != 0:
			fails.append("远嫁后风声应清零")

		# 8. has_incest 后不再触发被动事件
		var sis2 := {"name": "孟任", "surname": "姚", "gender": "female", "birth_year": -1068, "age": 22, "is_alive": true, "personality": "温和", "has_incest": true}
		GameState.family_data["siblings"].append(sis2)
		CharacterManager.init_sibling_affection(3)
		CharacterManager.set_sibling_affection(3, 95)
		var never_fired = true
		for _k in range(300):
			var evt = CharacterManager.check_sister_events(char)
			if not evt.is_empty():
				never_fired = false
				break
		if not never_fired:
			fails.append("has_incest 后不应再触发被动事件")

	if fails.is_empty():
		print("✅ P5-5 姐弟乱伦线测试通过：分娩通路/入口门槛/败露/继承剥夺/未成年gate/掩蔽远嫁")
	else:
		print("❌ P5-5 姐弟乱伦线测试失败：")
		for f in fails:
			print("  - " + f)
	get_tree().quit(0 if fails.is_empty() else 1)
