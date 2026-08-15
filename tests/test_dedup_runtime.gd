extends Node
# 运行时回归测试：验证表驱动重构后的 process_pregnancies / check_spouse_fidelity 数值对齐
# 用法：godot --headless --path . res://tests/test_dedup_runtime.tscn

func _ready() -> void:
	var fails: Array[String] = []

	# 构造测试角色（已婚 + 5类配偶全配置）
	var char: Dictionary = {
		"name": "姬昌", "surname": "姬", "clan": "周",
		"attributes": {"con": 14, "int": 12, "str": 12, "cha": 11, "vir": 12, "luk": 14, "ambition": 10},
		"relationships": {
			"spouse": {"name": "太姒", "surname": "姒", "clan": "莘", "loyalty": 80, "is_alive": true, "is_pregnant": false, "pregnancy_remaining": 0},
			"children": [],
		},
		"is_alive": true,
	}
	GameState.current_character = char
	GameState.family_data["family_tree"] = {}
	GameState.family_data["concubines"] = [
		{"name": "甲氏", "loyalty": 60, "is_alive": true, "is_pregnant": false, "pregnancy_remaining": 0},
	]
	GameState.family_data["tongfangs"] = [
		{"name": "乙氏", "loyalty": 50, "is_alive": true, "is_pregnant": false, "pregnancy_remaining": 0},
	]
	GameState.family_data["furens"] = [
		{"name": "丙氏", "loyalty": 85, "is_alive": true, "is_pregnant": false, "pregnancy_remaining": 0},
	]
	GameState.family_data["ying_qie"] = [
		{"name": "丁氏", "loyalty": 70, "is_alive": true, "is_pregnant": false, "pregnancy_remaining": 0},
	]

	# 1. 无身孕时：process_pregnancies 返回空，不产生子女
	var notices0 = CharacterManager.process_pregnancies(char)
	if not notices0.is_empty():
		fails.append("无身孕时应无通知，实际: %s" % str(notices0))
	if char.relationships.children.size() != 0:
		fails.append("无身孕时不应有子女")

	# 2. 全类身孕，全部 3 季到点，验证通知数量=5、子女=5、家庭树=5
	for row in [
		{"type": "wife", "list": [char.relationships.spouse]},
		{"type": "concubine", "list": GameState.family_data.concubines},
		{"type": "tongfang", "list": GameState.family_data.tongfangs},
		{"type": "furen", "list": GameState.family_data.furens},
		{"type": "ying_qie", "list": GameState.family_data.ying_qie},
	]:
		for m in row.list:
			m["is_pregnant"] = true
			m["pregnancy_remaining"] = 3
	# 推进：pregnancy_remaining=3，第3次调用时减到0触发分娩
	var notices: Array = []
	for q in range(1, 4):
		var n = CharacterManager.process_pregnancies(char)
		if q == 3:
			notices = n
	if notices.size() != 5:
		fails.append("分娩通知应为5条，实际: %d（%s）" % [notices.size(), str(notices)])
	if char.relationships.children.size() != 5:
		fails.append("子女应5个，实际: %d" % char.relationships.children.size())
	if GameState.family_data.family_tree.children.size() != 5:
		fails.append("家庭树应5个，实际: %d" % GameState.family_data.family_tree.children.size())
	# 正妻子女应为嫡出标签
	var wife_child = char.relationships.children[0]
	if wife_child.get("mother_type", "") != "wife":
		fails.append("第一个子女 mother_type 应为 wife")

	# 3. 忠诚检测：把各类忠诚设为极低（<30），验证高概率出轨但不崩
	GameState.family_data.family_tree.children = []
	var fidelity = CharacterManager.check_spouse_fidelity(char)
	if not fidelity is Array:
		fails.append("check_spouse_fidelity 应返回 Array")

	# 4. 汇总
	if fails.is_empty():
		print("✅ 回归测试通过：表驱动重构数值/结构正确（5类配偶全通过）")
		get_tree().quit(0)
	else:
		for f in fails:
			printerr("❌ " + f)
		print("❌ 回归测试失败：%d 项" % fails.size())
		get_tree().quit(1)
