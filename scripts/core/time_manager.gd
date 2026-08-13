# TimeManager.gd — 时间管理器（Autoload）
# 处理年/月/季节推进、人生阶段检测
extends Node

# ============================================================
# 时间常量
# ============================================================
enum Season { SPRING, SUMMER, AUTUMN, WINTER }

var current_season: int = Season.SPRING
var month: int = 1  # 当前月 1-12（每季推进3个月：春1→夏4→秋7→冬10）

# 季节推进信号：旧季节 / 新季节 / 年份，供节气·节庆·动画订阅
signal season_changed(old_season: int, new_season: int, year: int)

# ============================================================
# 二十四节气（按月排列，每季6气，季首即"立春/立夏/立秋/立冬"）
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
	# 月份随季节直接对齐（春1→夏4→秋7→冬10），并自愈旧档可能的不同步
	month = current_season * 3 + 1
	# 季节从冬回到春时，年份+1
	if current_season == Season.SPRING and old_season == Season.WINTER:
		GameState.current_year += 1
	season_changed.emit(old_season, current_season, GameState.current_year)
	return current_season

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
# 当前节气：游戏按"季"推进，故取本季起始节气（立春/立夏/立秋/立冬）
func get_current_solar_term() -> String:
	return SOLAR_TERMS[current_season * 6]

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
# 节庆查询（四时祭）
# ============================================================
# 当前季节庆，返回 {name, blessing}
func get_current_festival() -> Dictionary:
	return SEASON_RITES.get(current_season, {"name": "", "blessing": ""})

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
