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
var full_log: Array = []              # 完整史册（UI 只显示最近200行，此处全量保存；上限见 LOG_FULL_MAX_LINES）
var tutorial_done: bool = false       # 新手引导是否已完成（持久化，避免每局重复）
var last_births: Array = []           # 本季分娩结果（含难产/死胎/多胞胎），hud 消费弹窗后清空

# ============================================================
# 地图状态
# ============================================================
var current_location: String = "镐京"  # 当前位置
var explored_locations: Array = ["镐京"]  # 已探索地点

# ============================================================
# 成就 & 里程碑
# ============================================================
var achievements: Dictionary = {}   # 已解锁成就 {id: {"year": 解锁年份}}
var milestones: Dictionary = {}     # 已达成里程碑 {id: {"year": 达成年份}}

# ============================================================
# 信号定义
# ============================================================
signal year_changed(new_year: int)
signal character_updated(character: Dictionary)
signal event_triggered(event_data: Dictionary)
signal game_over(reason: String)
signal location_changed(new_location: String)
signal achievement_unlocked(achievement_id: String, achievement_name: String)
signal milestone_reached(milestone_id: String, milestone_name: String)

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
	check_achievements()
	check_milestones()

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
	check_achievements()

func log_event(event_id: String, choice_made: int, dice_result: String, effects: Array) -> void:
	event_history.append({
		"event_id": event_id,
		"year": current_year,
		"choice_made": choice_made,
		"dice_result": dice_result,
		"effects": effects
	})
	check_achievements()

# ============================================================
# 成就 & 里程碑系统
# ============================================================
# 数据驱动：新增成就/里程碑只需在对应定义表追加一条记录。
# type 支持：
#   start       游戏已开始（角色存在）
#   wealth      家族财富 >= value
#   reputation  角色声望 >= value
#   locations   已探索地点数 >= value
#   top_skill   最高技能等级 >= value
#   generation  家族代数 >= value
#   era         朝代进度 >= value（0.0-1.0）
#   events      已触发事件数 >= value
#   age         角色年龄 >= value
#   social      身份等级 >= value（1奴 2庶 3士 4卿大夫 5诸侯 6天子）
#   children    子女人数 >= value
#   heirloom    传家宝数量 >= value
const ACHIEVEMENT_DEFS := [
	{"id": "start",         "type": "start",      "value": 0,   "name": "初入周土", "desc": "开启华夏人生，踏上西周之路。"},
	{"id": "wealth_100",    "type": "wealth",     "value": 100, "name": "衣食无忧", "desc": "家族财富积累至100石。"},
	{"id": "wealth_1000",   "type": "wealth",     "value": 1000, "name": "富甲一方", "desc": "家族财富积累至1000石。"},
	{"id": "rep_100",       "type": "reputation", "value": 100, "name": "崭露头角", "desc": "家族声望达到100。"},
	{"id": "rep_500",       "type": "reputation", "value": 500, "name": "名动天下", "desc": "家族声望达到500。"},
	{"id": "loc_5",         "type": "locations",  "value": 5,   "name": "足迹四方", "desc": "探索5个不同地点。"},
	{"id": "skill_5",       "type": "top_skill",  "value": 5,   "name": "炉火纯青", "desc": "任意技能达到5级。"},
	{"id": "gen_3",         "type": "generation", "value": 3,   "name": "开枝散叶", "desc": "家族传承至第3代。"},
	{"id": "gen_5",         "type": "generation", "value": 5,   "name": "绵延不绝", "desc": "家族传承至第5代。"},
	{"id": "events_20",     "type": "events",     "value": 20,  "name": "阅尽千帆", "desc": "经历20次事件抉择。"},
	{"id": "children_3",    "type": "children",   "value": 3,   "name": "儿孙满堂", "desc": "膝下已有3名子女。"},
	{"id": "heirloom_3",    "type": "heirloom",   "value": 3,   "name": "传家之宝", "desc": "家族积累3件传家宝。"},
	{"id": "high_office",   "type": "social",     "value": 5,   "name": "位极人臣", "desc": "身份晋升为诸侯。"},
	{"id": "long_life",     "type": "age",        "value": 80,  "name": "仁者寿",   "desc": "寿至耄耋，享年八十。"},
]

const MILESTONE_DEFS := [
	{"id": "adult",    "type": "age", "value": 20, "name": "弱冠之年", "desc": "年满二十，行冠礼正式成人。"},
	{"id": "thirty",   "type": "age", "value": 30, "name": "而立之年", "desc": "三十而立，事业初成。"},
	{"id": "forty",    "type": "age", "value": 40, "name": "不惑之年", "desc": "四十不惑，处世清明。"},
	{"id": "fifty",    "type": "age", "value": 50, "name": "知命之年", "desc": "五十知天命。"},
	{"id": "sixty",    "type": "age", "value": 60, "name": "花甲之年", "desc": "六十花甲，历经风雨。"},
	{"id": "seventy",  "type": "age", "value": 70, "name": "古稀之年", "desc": "人生七十古来稀。"},
	{"id": "era_half", "type": "era", "value": 0.5, "name": "王朝过半", "desc": "亲历西周步入后半程。"},
	{"id": "era_end",  "type": "era", "value": 1.0, "name": "王朝落幕", "desc": "见证西周覆灭，历史翻页。"},
]

func check_achievements() -> Array:
	"""检查全部成就，解锁新达成的项，返回新解锁id列表。"""
	var newly: Array = []
	for entry in ACHIEVEMENT_DEFS:
		var id: String = entry.id
		if achievements.has(id):
			continue
		if _eval_def(entry):
			_unlock_entry(achievements, "成就", id, entry.name)
			newly.append(id)
			achievement_unlocked.emit(id, entry.name)
	return newly

func check_milestones() -> Array:
	"""检查全部里程碑，返回新达成id列表。"""
	var newly: Array = []
	for entry in MILESTONE_DEFS:
		var id: String = entry.id
		if milestones.has(id):
			continue
		if _eval_def(entry):
			_unlock_entry(milestones, "里程碑", id, entry.name)
			newly.append(id)
			milestone_reached.emit(id, entry.name)
	return newly

func unlock_achievement(achievement_id: String) -> bool:
	"""供外部按id直接解锁（如剧情达成），返回是否为新解锁。"""
	if achievements.has(achievement_id):
		return false
	var name := achievement_id
	for entry in ACHIEVEMENT_DEFS:
		if entry.id == achievement_id:
			name = entry.name
			break
	_unlock_entry(achievements, "成就", achievement_id, name)
	achievement_unlocked.emit(achievement_id, name)
	return true

func _eval_def(entry: Dictionary) -> bool:
	var value = entry.value
	match entry.type:
		"start":
			return not current_character.is_empty()
		"wealth":
			return family_data.get("wealth", 0) >= value
		"reputation":
			return current_character.get("reputation", 0) >= value
		"locations":
			return explored_locations.size() >= value
		"top_skill":
			return get_max_skill_level() >= value
		"generation":
			return family_data.get("generation_count", 1) >= value
		"era":
			return era_progress >= value
		"events":
			return event_history.size() >= value
		"age":
			return get_character_age() >= value
		"social":
			return current_character.get("social_level", 3) >= value
		"children":
			return current_character.get("relationships", {}).get("children", []).size() >= value
		"heirloom":
			return family_data.get("heirlooms", []).size() >= value
	return false

func _unlock_entry(store: Dictionary, label: String, id: String, display_name: String) -> void:
	store[id] = {"year": current_year}
	# 写入史册（成就/里程碑数量有限，无需裁剪）
	var line := "[color=#8fbc8f]〔%s·%d年〕🎊 达成%s「%s」！[/color]\n" % [
		TimeManager.get_season_name(), abs(current_year), label, display_name
	]
	full_log.append(line)

func get_character_age() -> int:
	"""当前主角年龄（未开局时返回0）。"""
	return current_year - current_character.get("birth_year", current_year)

func get_max_skill_level() -> int:
	"""当前主角最高技能等级。"""
	var max_level := 0
	for skill in current_character.get("skills", []):
		var parts = String(skill).split(":")
		if parts.size() == 2:
			max_level = maxi(max_level, int(parts[1]))
	return max_level

func get_achievement_count() -> int:
	return achievements.size()

func get_milestone_count() -> int:
	return milestones.size()

func get_unlocked_achievements() -> Array:
	return achievements.keys()

func get_unlocked_milestones() -> Array:
	return milestones.keys()

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
		"full_log": full_log,
		"tutorial_done": tutorial_done,
		"achievements": achievements,
		"milestones": milestones,
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
	full_log = save_data.get("full_log", [])
	tutorial_done = save_data.get("tutorial_done", false)
	achievements = save_data.get("achievements", {})
	milestones = save_data.get("milestones", {})
	# 旧档兼容：加载后立即补算成就/里程碑
	check_achievements()
	check_milestones()
	return "读档成功——回到公元前%d年，%s。" % [abs(current_year), current_location]

func has_save() -> bool:
	"""检查是否存在存档"""
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	"""删除存档"""
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
