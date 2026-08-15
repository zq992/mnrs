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
	# 扫描朝代目录，加载全部朝代JSON（为朝代更替预留多朝代支持）
	_all_dynasties.clear()
	_dynasty_list.clear()
	var dir := DirAccess.open("res://resources/dynasties/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				_load_dynasty_file("res://resources/dynasties/" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	# 兜底：目录扫描失败时仍尝试加载西周
	if _dynasty_list.is_empty():
		_load_dynasty_file("res://resources/dynasties/西周.json")
	# 按朝代起始年份升序排序（公元前为负数，最早的朝代在最前）
	_dynasty_list.sort_custom(_compare_dynasty_order)
	# 默认指向最早的朝代
	if not _dynasty_list.is_empty():
		_current_dynasty_data = _all_dynasties[_dynasty_list[0]]
	else:
		push_error("[DynastyManager] 未找到任何朝代数据")

func _load_dynasty_file(path: String) -> void:
	"""加载单个朝代JSON文件"""
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[DynastyManager] 无法加载: %s" % path)
		return
	var json = JSON.parse_string(file.get_as_text())
	file.close()
	if not (json is Dictionary) or json.is_empty():
		push_error("[DynastyManager] 朝代数据格式错误: %s" % path)
		return
	var id: String = json.get("id", "dynasty_%d" % _dynasty_list.size())
	_all_dynasties[id] = json
	_dynasty_list.append(id)
	print("[DynastyManager] 已加载朝代: %s" % json.get("name", "未知"))

func _compare_dynasty_order(a: String, b: String) -> bool:
	"""朝代排序比较器：按起始年份升序（公元前为负数，最早的朝代在前）"""
	return _all_dynasties[a].get("year_start", 0) < _all_dynasties[b].get("year_start", 0)

# ============================================================
# 查询接口
# ============================================================
func get_current_dynasty_data() -> Dictionary:
	_sync_current_dynasty()
	return _current_dynasty_data

func get_dynasty_name() -> String:
	_sync_current_dynasty()
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
# 朝代更替
# ============================================================
func set_current_dynasty(dynasty_id: String) -> bool:
	"""切换到指定朝代（朝代更替入口）"""
	if not _all_dynasties.has(dynasty_id):
		push_warning("[DynastyManager] 未找到朝代: %s" % dynasty_id)
		return false
	_current_dynasty_data = _all_dynasties[dynasty_id]
	if GameState:
		GameState.current_dynasty_id = dynasty_id
	print("[DynastyManager] 已切换朝代: %s" % _current_dynasty_data.get("name", "未知"))
	return true

func get_dynasty_for_year(year: int) -> Dictionary:
	"""返回该年份所属朝代数据（朝代更替查询）"""
	for id in _dynasty_list:
		var d: Dictionary = _all_dynasties[id]
		var start: int = d.get("year_start", 0)
		var end: int = d.get("year_end", 0)
		if year >= start and year <= end:
			return d
	# 超出所有朝代年份范围：返回最近的一个
	if _dynasty_list.is_empty():
		return {}
	if year < _all_dynasties[_dynasty_list[0]].get("year_start", 0):
		return _all_dynasties[_dynasty_list[0]]
	return _all_dynasties[_dynasty_list[-1]]

func get_next_dynasty_id() -> String:
	"""返回当前朝代的下一任朝代ID（无则返回空串）"""
	var idx: int = _dynasty_list.find(_current_dynasty_data.get("id", ""))
	if idx >= 0 and idx + 1 < _dynasty_list.size():
		return _dynasty_list[idx + 1]
	return ""

func _sync_current_dynasty() -> void:
	"""同步当前朝代：读档恢复 + 年份越过末期自动更替"""
	if not GameState:
		return
	var cur_id: String = _current_dynasty_data.get("id", "")
	# 1) 存档/读档指定了朝代 → 恢复为存档朝代
	var saved_id: String = GameState.current_dynasty_id
	if saved_id != "" and saved_id != cur_id and _all_dynasties.has(saved_id):
		_current_dynasty_data = _all_dynasties[saved_id]
		print("[DynastyManager] 读档恢复朝代: %s" % _current_dynasty_data.get("name", "未知"))
		return
	# 2) 当前年份已越过本朝末期 → 自动更替到下一朝代（可连续跨越多个朝代）
	while GameState.current_year > _current_dynasty_data.get("year_end", 0):
		var next_id := get_next_dynasty_id()
		if next_id == "":
			break  # 已是最后一朝，保持现状
		var old_name: String = _current_dynasty_data.get("name", "未知")
		_current_dynasty_data = _all_dynasties[next_id]
		GameState.current_dynasty_id = next_id
		print("[DynastyManager] 朝代更替: %s → %s" % [old_name, _current_dynasty_data.get("name", "未知")])

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
		if current_year >= start and current_year <= end:
			return king
	# 超出范围：开国前返回最早的王，亡国后返回最晚的王
	if not kings.is_empty():
		if current_year < kings[0].get("reign_start", 0):
			return kings[0]  # 开国前
		return kings[-1]  # 亡国后
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
