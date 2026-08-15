# TimeManager.gd — 时间管理器（Autoload）
# 处理年/月/季节推进、人生阶段检测
extends Node

# ============================================================
# 时间常量
# ============================================================
enum Season { SPRING, SUMMER, AUTUMN, WINTER }

var current_season: int = Season.SPRING
var solar_index: int = 0  # 二十四节气全局序号（0=立春 … 23=大寒），季首对齐"立X"
var month: int = 1  # 当前月 1-12（每气半月、每月两气；季首仍为 春1→夏4→秋7→冬10）

# 季节推进信号：旧季节 / 新季节 / 年份，供节气·节庆·动画订阅
signal season_changed(old_season: int, new_season: int, year: int)
# 节气推进信号：旧节气序号 / 新节气序号，供 HUD·事件按节气触发
signal solar_term_changed(old_index: int, new_index: int)

# ============================================================
# 二十四节气（按月排列，每季6气，序号0-23，季首即"立春/立夏/立秋/立冬"）
# ============================================================
const SOLAR_TERMS := [
	"立春", "雨水", "惊蛰", "春分", "清明", "谷雨",
	"立夏", "小满", "芒种", "夏至", "小暑", "大暑",
	"立秋", "处暑", "白露", "秋分", "寒露", "霜降",
	"立冬", "小雪", "大雪", "冬至", "小寒", "大寒",
]

# ============================================================
# 四时节庆（西周宗庙四时祭）：春礿 / 夏禘 / 秋尝 / 冬烝
# ============================================================
const SEASON_RITES := {
	Season.SPRING: {"name": "春祭·礿", "blessing": "祀先祖、祈丰年，四时祭之始"},
	Season.SUMMER: {"name": "夏祭·禘", "blessing": "序昭穆、祭祖考，报夏之盛德"},
	Season.AUTUMN: {"name": "秋祭·尝", "blessing": "荐新谷于先祖，报秋成之喜"},
	Season.WINTER: {"name": "冬祭·烝", "blessing": "岁末大祭进品物，合聚先祖之灵"},
}

# ============================================================
# 季节推进
# ============================================================
func advance_season() -> int:
	var old_season = current_season
	current_season = (current_season + 1) % 4
	# 季首节气对齐（立春/立夏/立秋/立冬），月份随之自愈旧档可能的不同步
	_set_solar_index(current_season * 6)
	# 季节从冬回到春时，年份+1
	if current_season == Season.SPRING and old_season == Season.WINTER:
		GameState.current_year += 1
	season_changed.emit(old_season, current_season, GameState.current_year)
	return current_season

# 季内逐气推进（可选）：跨季边界时自动交给 advance_season 统一推进季节/年份
func advance_solar_term() -> int:
	var next := (solar_index + 1) % 24
	if next % 6 == 0:
		advance_season()
	else:
		_set_solar_index(next)
	return solar_index

# 内部：更新节气序号并同步月份与节气信号（季节推进时也会调用）
func _set_solar_index(new_index: int) -> void:
	var old := solar_index
	solar_index = new_index % 24
	month = solar_index / 2 + 1  # 每月两气，由节气序号推导 1-12 月
	if old != solar_index:
		solar_term_changed.emit(old, solar_index)

func get_season_name() -> String:
	match current_season:
		Season.SPRING: return "春"
		Season.SUMMER: return "夏"
		Season.AUTUMN: return "秋"
		_: return "冬"

func get_season_movement_modifier() -> float:
	# 季节对移动消耗的影响
	match current_season:
		Season.SPRING: return 1.1   # 春雨泥泞
		Season.SUMMER: return 1.0
		Season.AUTUMN: return 0.9   # 秋高气爽
		_: return 1.5   # 冬季大雪

# ============================================================
# 节气查询（二十四节气）
# ============================================================
# 当前节气：默认季首（立春/立夏/立秋/立冬），可经 advance_solar_term 逐气推进
func get_current_solar_term() -> String:
	return SOLAR_TERMS[solar_index]

# 当前节气序号（0-23）
func get_current_solar_index() -> int:
	return solar_index

# 按名称查节气序号（未找到返回 -1）
func get_solar_term_index(term_name: String) -> int:
	return SOLAR_TERMS.find(term_name)

# 某季全部6个节气（season 缺省为当前季，0春/1夏/2秋/3冬）
func get_season_solar_terms(season: int = -1) -> Array:
	var s: int = current_season if season < 0 else season
	var start: int = s * 6
	return SOLAR_TERMS.slice(start, start + 6)

# 按序号取节气名（0-23，越界返回空串）
func get_solar_term_name(index: int) -> String:
	if index < 0 or index >= SOLAR_TERMS.size():
		return ""
	return SOLAR_TERMS[index]

# ============================================================
# 节庆查询（四时祭 + 二分二至专祭）
# ============================================================
# 节气专祭（二分二至）：春分祭日 / 夏至祭地 / 秋分祭月 / 冬至祭天
const TERM_RITES := {
	3:  {"name": "春分·祭日", "blessing": "春分朝日于东郊，顺阴阳而和生"},
	9:  {"name": "夏至·祭地", "blessing": "夏至祭地于北郊，祈甘雨足百谷"},
	15: {"name": "秋分·祭月", "blessing": "秋分夕月于西郊，报秋成而致月"},
	21: {"name": "冬至·祭天", "blessing": "冬至祀天于南郊，一阳来复祈新岁"},
}

# 当前节庆，返回 {name, blessing}：节气专祭优先，其余回落四时祭
func get_current_festival() -> Dictionary:
	return TERM_RITES.get(solar_index, SEASON_RITES.get(current_season, {"name": "", "blessing": ""}))

# 某节气序号的专祭（无则返回空字典）
func get_term_festival(index: int) -> Dictionary:
	return TERM_RITES.get(index, {})

# 某季节庆名（season 缺省为当前季）
func get_festival_name(season: int = -1) -> String:
	var s: int = current_season if season < 0 else season
	var rite: Dictionary = SEASON_RITES.get(s, {})
	return rite.get("name", "")

# ============================================================
# 人生阶段检测
# ============================================================
enum LifeStage { INFANT, TODDLER, CHILD, TEEN, YOUNG, ADULT, MIDDLE_AGE, OLD_AGE, ELDER }

func get_life_stage(age: int) -> int:
	if age < 3:
		return LifeStage.INFANT
	elif age < 6:
		return LifeStage.TODDLER
	elif age < 12:
		return LifeStage.CHILD
	elif age < 16:
		return LifeStage.TEEN
	elif age < 20:
		return LifeStage.YOUNG
	elif age < 35:
		return LifeStage.ADULT
	elif age < 50:
		return LifeStage.MIDDLE_AGE
	elif age < 65:
		return LifeStage.OLD_AGE
	return LifeStage.ELDER

func get_life_stage_name(stage: int) -> String:
	match stage:
		LifeStage.INFANT: return "婴儿"
		LifeStage.TODDLER: return "幼儿"
		LifeStage.CHILD: return "少年"
		LifeStage.TEEN: return "成童"
		LifeStage.YOUNG: return "青年"
		LifeStage.ADULT: return "壮年"
		LifeStage.MIDDLE_AGE: return "中年"
		LifeStage.OLD_AGE: return "老年"
		_: return "暮年"

# ============================================================
# 自然死亡判定
# ============================================================
func check_natural_death(age: int, con: int) -> bool:
	# 西周人均寿命约40岁，基础寿命35+1d15（36~50岁）
	var natural_lifespan = 35 + randi_range(1, 15)
	if age < natural_lifespan:
		return false

	# 超过自然寿命后每季递增死亡概率
	var years_over = age - natural_lifespan
	var death_probability = 0.06 + years_over * 0.05
	# 体质每高2点降低约1%概率
	death_probability -= (con - 10) * 0.01
	death_probability = clampf(death_probability, 0.02, 0.60)

	return randf() < death_probability
