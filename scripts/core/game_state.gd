# GameState.gd — 全局游戏状态管理（Autoload 单例）
# 所有 Manager 通过此单例通信
extends Node

# ============================================================
# 当前游戏状态
# ============================================================
var current_year: int = -1046          # 当前年份（负数=公元前）
var current_dynasty_id: String = ""    # 当前朝代ID
var current_character: Dictionary = {} # 当前角色数据
var is_war_state: bool = false         # 是否处于战争状态
var era_progress: float = 0.0          # 朝代进度 0.0-1.0
var game_started: bool = false         # 游戏是否已开始

# 声望停滞跟踪
var reputation_stall_seasons: int = 0   # 声望连续未增长的季数
var last_stall_check_rep: int = 0       # 上次检测时的声望值

# ============================================================
# 家族数据
# ============================================================
var family_data: Dictionary = {
	"surname": "",           # 姓
	"clan": "",              # 氏
	"generation_count": 1,   # 当前代数
	"reputation": 0,         # 家族声望
	"wealth": 0,             # 家族财富（石）
	"heirlooms": [],         # 传家宝
	"family_tree": {},       # 家族树
	"siblings": [],          # 兄弟姐妹
	"concubines": [],        # 妾室列表
	"branch_families": [],   # 分家支系
	"infidelity_log": [],   # 出轨记录
	"incest_log": [],        # 乱伦记录
	"scandal_level": 0       # 丑闻等级 0-5
}

# 家庭数据（日常起居层级——同居成员、和睦、家务）
var household_data: Dictionary = {
	"harmony": 60,            # 家庭和睦度 0-100
	"wealth": 0,              # 家庭私财（石）
	"servants": [],           # 仆从
	"member_relations": {},   # 成员间关系 {id: {other_id: opinion}}
	"events": [],             # 家庭事件日志
}

# ============================================================
# 事件历史
# ============================================================
var event_history: Array = []         # 已触发事件记录
var completed_timeline_events: Array = []  # 已完成的时间线事件

# ============================================================
# 地图状态
# ============================================================
var current_location: String = "镐京"  # 当前位置
var explored_locations: Array = ["镐京"]  # 已探索地点

# ============================================================
# 信号定义
# ============================================================
signal year_changed(new_year: int)
signal character_updated(character: Dictionary)
signal event_triggered(event_data: Dictionary)
signal game_over(reason: String)
signal location_changed(new_location: String)

# ============================================================
# 公共方法
# ============================================================

func is_game_over() -> bool:
	return not current_character.get("is_alive", true)

func get_current_year_display() -> String:
	if current_year < 0:
		return "公元前%d年" % abs(current_year)
	else:
		return "公元%d年" % current_year

func advance_time(years: int = 1) -> void:
	current_year += years
	year_changed.emit(current_year)
	_update_era_progress()

func _update_era_progress() -> void:
	var dynasty_data = DynastyManager.get_current_dynasty_data()
	if dynasty_data.is_empty():
		return
	var start_year = dynasty_data.get("year_start", -1046)
	var end_year = dynasty_data.get("year_end", -771)
	var total_years = end_year - start_year
	if total_years > 0:
		era_progress = clampf(float(current_year - start_year) / float(total_years), 0.0, 1.0)

func change_location(location: String) -> void:
	current_location = location
	if location not in explored_locations:
		explored_locations.append(location)
	location_changed.emit(location)

func log_event(event_id: String, choice_made: int, dice_result: String, effects: Array) -> void:
	event_history.append({
		"event_id": event_id,
		"year": current_year,
		"choice_made": choice_made,
		"dice_result": dice_result,
		"effects": effects
	})

# ============================================================
# 存档/读档
# ============================================================
const SAVE_PATH := "user://savegame.json"

func save_game() -> String:
	"""保存游戏，返回结果消息"""
	var save_data := {
		"current_year": current_year,
		"current_dynasty_id": current_dynasty_id,
		"current_character": current_character,
		"is_war_state": is_war_state,
		"era_progress": era_progress,
		"game_started": game_started,
		"reputation_stall_seasons": reputation_stall_seasons,
		"last_stall_check_rep": last_stall_check_rep,
		"family_data": family_data,
		"household_data": household_data,
		"event_history": event_history,
		"completed_timeline_events": completed_timeline_events,
		"current_location": current_location,
		"explored_locations": explored_locations,
	}
	var json_str := JSON.stringify(save_data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return "存档失败：无法写入文件。"
	file.store_string(json_str)
	file.close()
	return "存档成功——公元前%d年，%s。" % [abs(current_year), current_location]

func load_game() -> String:
	"""读取存档，返回结果消息"""
	if not FileAccess.file_exists(SAVE_PATH):
		return "无存档记录。"
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return "读档失败：无法读取文件。"
	var json_str := file.get_as_text()
	file.close()
	var save_data = JSON.parse_string(json_str)
	if save_data == null:
		return "读档失败：存档数据损坏。"
	# 恢复状态
	current_year = save_data.get("current_year", -1046)
	current_dynasty_id = save_data.get("current_dynasty_id", "")
	current_character = save_data.get("current_character", {})
	is_war_state = save_data.get("is_war_state", false)
	era_progress = save_data.get("era_progress", 0.0)
	game_started = save_data.get("game_started", true)
	reputation_stall_seasons = save_data.get("reputation_stall_seasons", 0)
	last_stall_check_rep = save_data.get("last_stall_check_rep", current_character.derived.get("reputation", 0))
	family_data = save_data.get("family_data", {})
	household_data = save_data.get("household_data", {"harmony": 60, "wealth": 0, "servants": [], "member_relations": {}, "events": []})
	event_history = save_data.get("event_history", [])
	completed_timeline_events = save_data.get("completed_timeline_events", [])
	current_location = save_data.get("current_location", "镐京")
	explored_locations = save_data.get("explored_locations", ["镐京"])
	return "读档成功——回到公元前%d年，%s。" % [abs(current_year), current_location]

func has_save() -> bool:
	"""检查是否存在存档"""
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	"""删除存档"""
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
