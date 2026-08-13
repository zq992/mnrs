# DynastyManager.gd — 朝代管理器（Autoload）
# 加载朝代JSON数据，提供查询接口
extends Node

# ============================================================
# 数据存储
# ============================================================
var _current_dynasty_data: Dictionary = {}
var _all_dynasties: Dictionary = {}    # dynasty_id → data
var _dynasty_list: Array = []          # 所有朝代ID列表

# ============================================================
# 初始化
# ============================================================
func _ready() -> void:
	_load_dynasty_data()

func _load_dynasty_data() -> void:
	var file = FileAccess.open("res://resources/dynasties/西周.json", FileAccess.READ)
	if file:
		var text = file.get_as_text()
		var json = JSON.parse_string(text)
		if json:
			_current_dynasty_data = json
			_all_dynasties[json.get("id", "western_zhou")] = json
			_dynasty_list.append(json.get("id", "western_zhou"))
			print("[DynastyManager] 已加载朝代: %s" % json.get("name", "未知"))
		file.close()
	else:
		push_error("[DynastyManager] 无法加载西周.json")

# ============================================================
# 查询接口
# ============================================================
func get_current_dynasty_data() -> Dictionary:
	return _current_dynasty_data

func get_dynasty_name() -> String:
	return _current_dynasty_data.get("name", "未知")

func get_dynasty_id() -> String:
	return _current_dynasty_data.get("id", "unknown")

func get_social_classes() -> Array:
	return _current_dynasty_data.get("social_classes", [])

func get_professions_for_class(social_class: String) -> Array:
	var all_professions = _current_dynasty_data.get("professions", {})
	return all_professions.get(social_class, [])

func get_map_data() -> Dictionary:
	return _current_dynasty_data.get("map", {})

func get_cities() -> Array:
	return _current_dynasty_data.get("map", {}).get("cities", [])

func get_surrounding_threats() -> Array:
	return _current_dynasty_data.get("map", {}).get("threats", [])

func get_rebellion_paths() -> Array:
	return _current_dynasty_data.get("rebellion_paths", [])

func get_available_origins() -> Array:
	return _current_dynasty_data.get("available_origins", ["士"])

func get_ethnicity() -> String:
	return _current_dynasty_data.get("default_ethnicity", "华族")

func get_year_start() -> int:
	return _current_dynasty_data.get("year_start", -1046)

func get_year_end() -> int:
	return _current_dynasty_data.get("year_end", -771)

# ============================================================
# 地图数据
# ============================================================
func get_city_by_name(city_name: String) -> Dictionary:
	for city in get_cities():
		if city.get("name", "") == city_name:
			return city
	return {}

func get_location_info(location_name: String) -> Dictionary:
	# 检查城市
	var city = get_city_by_name(location_name)
	if not city.is_empty():
		return {"type": "city", "data": city}

	# 检查资源点
	var resources = get_map_data().get("resources", [])
	for res in resources:
		if res.get("name", "") == location_name:
			return {"type": "resource", "data": res}

	# 检查特殊点
	var special = get_map_data().get("special_locations", [])
	for sp in special:
		if sp.get("name", "") == location_name:
			return {"type": "special", "data": sp}

	return {"type": "unknown", "data": {"name": location_name}}


# ============================================================
# 周王系统
# ============================================================
func get_current_king(current_year: int = 0) -> Dictionary:
	"""返回当前在位周王信息"""
	if current_year == 0:
		current_year = GameState.current_year if GameState else -1046
	var kings = _current_dynasty_data.get("kings", [])
	for king in kings:
		var start: int = king.get("reign_start", 0)
		var end: int = king.get("reign_end", 0)
		if current_year <= start and current_year >= end:
			return king
	# 超出范围返回最后一个王
	if not kings.is_empty():
		if current_year > kings[0].get("reign_start", 0):
			return kings[0]  # 最早的（开国前）
		return kings[-1]  # 最晚的（亡国后）
	return {"name": "周王", "given_name": "?", "era": "未知", "desc": ""}


func get_king_background_path(current_year: int = 0) -> String:
	"""根据当前周王返回背景图路径。开局返回周公教导图"""
	var king = get_current_king(current_year)
	var era: String = king.get("era", "")
	# 开局使用周公教导图（成王初期）
	if era == "周公辅政" or era == "克商建周":
		return "res://resources/textures/backgrounds/zhougong_teaching.png"
	# 后期暂时复用已有背景
	return "res://resources/textures/backgrounds/city_haojing.png"
