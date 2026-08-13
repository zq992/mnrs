# TimeManager.gd — 时间管理器（Autoload）
# 处理年/月/季节推进、人生阶段检测
extends Node

# ============================================================
# 时间常量
# ============================================================
enum Season { SPRING, SUMMER, AUTUMN, WINTER }

var current_season: int = Season.SPRING
var month: int = 1  # 1-12

# ============================================================
# 季节推进
# ============================================================
func advance_season() -> int:
	var old_season = current_season
	current_season = (current_season + 1) % 4
	# 季节从冬回到春时，年份+1
	if current_season == Season.SPRING and old_season == Season.WINTER:
		GameState.current_year += 1
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
