extends Node
# 玩法路径冒烟测试：推进/履职/修习/快捷键/忠诚等真实路径（用真实 create_character）
# 用法：godot --headless --path . res://tests/test_gameplay.tscn

func _ready() -> void:
	var fails: Array[String] = []
	var char: Dictionary = CharacterManager.create_character({
		"name": "昌", "surname": "姬", "clan": "周", "age": 20,
		"profession": "小吏", "social_level": 1,
		"attr_bonus": {"con": 4, "int": 4, "luk": 6},
	})
	GameState.current_character = char
	GameState.family_data["family_tree"] = {}
	GameState.family_data["wealth"] = 100
	GameState.current_year = -1046

	var game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in range(5):
		await get_tree().process_frame

	# 1. 推进一季（覆盖季节信号/死亡检查/事件触发路径）
	game._on_advance_time()
	await get_tree().process_frame

	# 2. 履职（正常模式）——覆盖 toast + 收入路径
	game._on_work_execute("normal", null)
	await get_tree().process_frame

	# 3. 修习——覆盖 _apply_study_once 快速路径
	game._last_study_mode = "self"
	game._last_study_skill = "书数"
	game._study_quick()
	await get_tree().process_frame

	# 4. 一键履职（记忆强度复用）
	game._work_quick()
	await get_tree().process_frame

	# 5. 忠诚检测（跑通表驱动，真实角色字段完整）
	var fid = CharacterManager.check_spouse_fidelity(char)
	if not fid is Array:
		fails.append("check_spouse_fidelity 返回类型错误")

	# 6. 气运点 roll_with_fate 跑通
	var fate = DiceSystem.roll_with_fate(18, "2d6", 1, 0)
	if not fate.has("result") or not fate.has("rerolled"):
		fails.append("roll_with_fate 返回结构错误")

	if fails.is_empty():
		print("✅ 玩法冒烟测试通过：推进/履职/修习/快捷键/忠诚/气运全路径无错误")
	else:
		for f in fails:
			printerr("❌ " + f)
	get_tree().quit(0 if fails.is_empty() else 1)
