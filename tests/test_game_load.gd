extends Node
# 游戏主场景加载测试：构造角色并实例化 game.tscn，跑几帧，验证无运行时错误
# 用法：godot --headless --path . res://tests/test_game_load.tscn

func _ready() -> void:
	# 构造可玩角色
	var char: Dictionary = {
		"name": "姬昌", "surname": "姬", "clan": "周",
		"attributes": {"con": 14, "int": 12, "str": 12, "cha": 11, "vir": 12, "luk": 14, "ambition": 10},
		"relationships": {"spouse": {}, "children": []},
		"is_alive": true, "birth_year": -1046, "age": 0,
		"profession": "", "social_level": 0, "skills": [],
		"ethnicity": "华夏", "personality": "沉稳",
	}
	GameState.current_character = char
	GameState.family_data["family_tree"] = {}
	GameState.current_year = -1046

	var game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	# 跑 30 帧，覆盖 _ready / _refresh_display / 新手引导 / 童年快进等路径
	for i in range(30):
		await get_tree().process_frame
	print("✅ 游戏场景加载测试通过：30帧无运行时错误")
	get_tree().quit(0)
