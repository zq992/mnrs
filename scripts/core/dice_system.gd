# DiceSystem.gd — 骰子系统（Autoload）
# 2d6 + 属性加值 + 运气修正 → 4段结果
extends Node

# ============================================================
# 核心骰子方法
# ============================================================

# 掷骰：返回 {roll_value, final_value, outcome_tier, outcome_text}
func roll_dice(dice_formula: String = "2d6", attr_bonus: int = 0, luck_mod: int = 0,
               outcomes: Dictionary = {}) -> Dictionary:
	# 解析骰子公式（当前仅支持 2d6）
	var roll_value = _roll_2d6()
	var final_value = roll_value + attr_bonus + luck_mod

	# 匹配结果段
	var tier = _determine_tier(final_value)

	return {
		"roll_value": roll_value,
		"attr_bonus": attr_bonus,
		"luck_mod": luck_mod,
		"final_value": final_value,
		"tier": tier,
		"tier_name": _tier_name(tier),
		"tier_description": _tier_description(tier)
	}

func _roll_2d6() -> int:
	return randi_range(1, 6) + randi_range(1, 6)

func _determine_tier(final_value: int) -> int:
	# 4段结果映射
	if final_value >= 13:
		return 0  # CRITICAL 大成功
	elif final_value >= 9:
		return 1  # SUCCESS 成功
	elif final_value >= 5:
		return 2  # PARTIAL 部分成功
	else:
		return 3  # FAILURE 失败

func _tier_name(tier: int) -> String:
	match tier:
		0: return "大成功"
		1: return "成功"
		2: return "部分成功"
		_: return "失败"

func _tier_description(tier: int) -> String:
	match tier:
		0: return "超乎预期的绝佳结果！"
		1: return "事情按计划顺利进行。"
		2: return "勉强达成，但付出了额外的代价。"
		_: return "事与愿违，情况变得更糟了。"

# ============================================================
# 属性→骰子加值映射（非线性）
# ============================================================
func attr_to_bonus(attr_value: int) -> int:
	match attr_value:
		1, 2, 3, 4, 5:
			return -2   # 极低——严重惩罚
		6, 7, 8, 9, 10:
			return -1   # 较低——轻度惩罚
		# 11-14：故意平坦区间——中等属性不影响骰子
		15, 16, 17:
			return 1    # 优秀——轻度加成
		18, 19, 20:
			return 2    # 卓越——显著加成
		_:
			return 3 if attr_value >= 21 else 0

# ============================================================
# 属性加权判定（属性 → 加值 → 掷骰 → 判定，一步到位）
# ============================================================
# 直接传「属性原始值」即可完成一次加权判定，内部复用 attr_to_bonus + roll_dice。
# 返回结构与 roll_dice 完全兼容（tier / roll_value / final_value 平铺可读），
# 并额外附带 attr_value / difficulty / success / margin 字段，旧调用不受影响。
# difficulty：判定难度目标值，默认 7（2d6 均值，普通难度）；<=0 时无门槛，退化为纯加权掷骰。
# margin：最终值 - 难度，正为成功度（超出多少）、负为失败度（差多少）。
func roll_attribute_check(attr_value: int, difficulty: int = 7, luck_mod: int = 0,
                          dice_formula: String = "2d6") -> Dictionary:
	var attr_bonus = attr_to_bonus(attr_value)                    # 属性 → 加值（非线性映射）
	var result = roll_dice(dice_formula, attr_bonus, luck_mod)    # 掷骰 → 4 段结果
	var check = result.duplicate()                                # 铺平旧结果，保持超集兼容
	check["attr_value"] = attr_value
	check["difficulty"] = difficulty
	check["success"] = difficulty <= 0 or result.final_value >= difficulty
	check["margin"] = result.final_value - difficulty
	return check

# ============================================================
# 加权随机选择
# ============================================================
func weighted_random_select(items: Array, weight_key: String = "weight") -> Dictionary:
	var total_weight: float = 0.0
	for item in items:
		total_weight += item.get(weight_key, 1.0)

	if total_weight <= 0:
		return {}

	var roll = randf() * total_weight
	var cumulative: float = 0.0
	for item in items:
		cumulative += item.get(weight_key, 1.0)
		if roll <= cumulative:
			return item

	return items.back() if not items.is_empty() else {}

# ============================================================
# 概率判定
# ============================================================
func roll_chance(probability: float) -> bool:
	# probability: 0.0 - 1.0
	return randf() < probability
