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
# 气运点重掷（天命所归）：关键掷骰失败时消耗气运再赌一次
# 气运 ≥15 且首掷非大成功/成功时，可重掷一次，消耗 2 点气运
# ============================================================
func roll_with_fate(luk_value: int, dice_formula: String = "2d6",
                    attr_bonus: int = 0, luck_mod: int = 0) -> Dictionary:
	var first := roll_dice(dice_formula, attr_bonus, luck_mod)
	# 气运不足，或首掷已是大成功/成功，直接返回
	if luk_value < 15 or first.tier <= 1:
		return {"result": first, "rerolled": false, "fate_cost": 0, "first": {}}
	var second := roll_dice(dice_formula, attr_bonus, luck_mod)
	return {"result": second, "rerolled": true, "fate_cost": 2, "first": first}

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
# 并额外附带 attr_value / difficulty / success / margin 字段。
# difficulty：判定难度目标值，默认 7（2d6 均值，普通难度）；<=0 时无门槛，退化为纯加权掷骰。
# margin：最终值 - 难度，正为成功度（超出多少）、负为失败度（差多少）。
# 有门槛（difficulty>0）时，tier 按 margin 相对难度重新定级，保证 tier/success/margin 三者自洽；
# 无门槛时保留 roll_dice 的绝对档位（大成功13 / 成功9 / 部分成功5）。
func roll_attribute_check(attr_value: int, difficulty: int = 7, luck_mod: int = 0,
                          dice_formula: String = "2d6") -> Dictionary:
	var attr_bonus = attr_to_bonus(attr_value)                    # 属性 → 加值（非线性映射）
	var result = roll_dice(dice_formula, attr_bonus, luck_mod)    # 掷骰 → 原始结果
	var check = result.duplicate()                                # 铺平旧结果，保持键名兼容
	check["attr_value"] = attr_value
	check["difficulty"] = difficulty
	# 无门槛：退化为纯加权掷骰，不设成败，margin 归零避免被负难度虚增
	if difficulty <= 0:
		check["success"] = true
		check["margin"] = 0
		return check
	# 有门槛：以 margin 相对难度定级，避免「tier=成功 但 success=false」的自相矛盾
	var margin: int = result.final_value - difficulty
	check["success"] = margin >= 0
	check["margin"] = margin
	var tier: int
	if margin >= 4:
		tier = 0    # 大成功：远超目标
	elif margin >= 0:
		tier = 1    # 成功：达到目标
	elif margin >= -2:
		tier = 2    # 部分成功：差一点达成
	else:
		tier = 3    # 失败：明显未达标
	check["tier"] = tier
	check["tier_name"] = _tier_name(tier)
	check["tier_description"] = _tier_description(tier)
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
