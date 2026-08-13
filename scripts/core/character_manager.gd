# CharacterManager.gd — 角色管理器（Autoload）
# 角色创建、属性管理、身份跃迁、技能系统
extends Node

# ============================================================
# 常量定义
# ============================================================
const SOCIAL_CLASSES = {
	1: {"name": "奴隶", "level": 1, "display": "奴隶/贱民"},
	2: {"name": "庶人", "level": 2, "display": "庶民/布衣"},
	3: {"name": "士", "level": 3, "display": "士/官吏"},
	4: {"name": "卿大夫", "level": 4, "display": "卿大夫/将军"},
	5: {"name": "诸侯", "level": 5, "display": "诸侯/王"},
	6: {"name": "天子", "level": 6, "display": "天子"},
}

# 家兵容量（按等级）
const TROOP_CAPACITY = {
	1: 0,      # 奴隶——无兵权
	2: 0,      # 庶人——无兵权
	3: 0,      # 士——无采邑，不养私兵
	4: 200,    # 卿大夫——有采邑，可养私兵
	5: 2000,   # 诸侯——一国之军
	6: 10000,  # 天子——天下共主
}

# 兵种定义
const TROOP_TYPES = {
	"步兵": {"cost": 2, "power_per_50": 1, "min_level": 4, "desc": "持戈步卒，基础作战力量"},
	"车兵": {"cost": 5, "power_per_50": 2, "min_level": 5, "desc": "乘战车作战的甲士，冲击力强"},
	"王师": {"cost": 10, "power_per_50": 3, "min_level": 6, "desc": "天子亲卫，天下精锐"},
}

# 兵种上限（按等级）
const TROOP_LIMITS = {
	4: {"步兵": 200},
	5: {"步兵": 1000, "车兵": 200},
	6: {"步兵": 5000, "车兵": 1000, "王师": 500},
}

# 妻妾通房上限（按等级）
const SPOUSE_LIMITS = {
	1: {"wife": 0, "concubine": 0, "tongfang": 0, "furen": 0, "ying_qie": 0},
	2: {"wife": 1, "concubine": 0, "tongfang": 0, "furen": 0, "ying_qie": 0},
	3: {"wife": 1, "concubine": 1, "tongfang": 1, "furen": 0, "ying_qie": 0},
	4: {"wife": 1, "concubine": 2, "tongfang": 2, "furen": 0, "ying_qie": 0},   # 卿大夫
	5: {"wife": 1, "concubine": 4, "tongfang": 4, "furen": 0, "ying_qie": 3},   # 诸侯——媵妾制
	6: {"wife": 1, "concubine": 8, "tongfang": 6, "furen": 3, "ying_qie": 0},   # 天子——夫人制
}

# 通房丫头花费
const TONGFANG_COST_BASE = 15

# 等级俸禄（每季）
const LEVEL_STIPEND = {
	1: 0,      # 奴隶——无俸禄
	2: 10,     # 庶人——耕作自足
	3: 30,     # 士——低级官吏常俸
	4: 120,    # 卿大夫——采邑税入
	5: 500,    # 诸侯——封国赋税
	6: 1500,   # 天子——王畿之利
}

# 等级义务性支出（每季自动扣除）
const LEVEL_EXPENSES = {
	1: 0,      # 奴隶——无
	2: 0,      # 庶人——无
	3: 0,      # 士——无额外义务
	4: 30,     # 卿大夫——养私兵+家臣
	5: 200,    # 诸侯——养兵+朝贡+祭祀
	6: 800,    # 天子——王师+祭祀+赏赐
}

# 各身份生育率（每季基础受孕概率 %）
const FERTILITY_RATES = {
	"wife": 20.0,       # 正妻——最高
	"furen": 15.0,      # 夫人——天子后宫，次高
	"ying_qie": 14.0,   # 媵妾——诸侯侧室
	"concubine": 12.0,  # 妾室——中等
	"tongfang": 7.0,    # 通房——较低
}

# 家庭和睦度影响因素
const HARMONY_FACTORS = {
	"wife_loyal": 8,           # 正妻忠诚>70
	"wife_discontent": -6,     # 正妻忠诚<40
	"concubine_discontent": -4, # 每位不忠妾室
	"new_concubine_jealousy": -5, # 新纳妾/收通房
	"scandal_penalty": -8,     # 丑闻>2
	"child_educated": 3,       # 子女在受教育
	"adult_child_crowded": -3, # 成年子女仍居家中
	"pregnancy_bonus": 4,      # 有人怀孕
	"birth_bonus": 6,          # 婴儿降生
	"death_penalty": -10,      # 家人去世
	"heir_designated": 5,      # 已立嗣
	"wealth_stress": -5,       # 家庭私财<0
}

# 子女身份标签（按母类型）
const CHILD_STATUS_LABELS = {
	"wife": "嫡出",
	"furen": "贵子",
	"ying_qie": "媵出",
	"concubine": "庶出",
	"tongfang": "婢生",
}

# 朝廷官职（按国家区分）
# 可封诸侯国（排除周王畿）
const FEUDAL_STATES = ["鲁国", "齐国", "晋国", "卫国", "燕国", "蔡国", "曹国", "虢国", "吴国", "宋国", "陈国", "杞国", "楚国", "许国", "申国", "纪国"]

const COURT_POSITIONS = {
	"周王畿": ["冢宰", "司徒", "司马", "司寇", "司空", "大宗伯", "小宗伯", "大夫"],
	"default": ["大夫", "司马", "司徒", "司寇", "邑宰"],
}

const BASE_ATTRIBUTES = ["con", "int", "str", "cha", "vir", "luk"]
const ATTR_NAMES = {
	"con": "体质", "int": "智力", "str": "武力",
	"cha": "魅力", "vir": "德行", "luk": "气运"
}

const SKILLS = ["礼法", "射御", "书数", "乐", "兵法", "医术", "游说"]

const SKILL_TO_ATTR: Dictionary = {
	"礼法": "vir", "射御": "str", "书数": "int",
	"乐": "cha", "兵法": "str", "医术": "int", "游说": "cha",
}

# 出轨/乱伦系统常量
const INCEST_RELATIONS = ["father", "mother", "sibling", "child"]
const SCANDAL_PENALTIES = {
	"minor": {"rep": -10, "label": "坊间流言"},
	"major": {"rep": -20, "label": "丑闻败露"},
	"severe": {"rep": -35, "label": "身败名裂"},
}

# 好感度等级
const AFFECTION_LABELS = {
	80: "亲密无间",
	50: "手足情深",
	20: "相处和睦",
	-20: "关系平平",
	-50: "心存芥蒂",
	-100: "反目成仇",
}

# 西周八大姓
const EIGHT_SURNAMES = ["姬", "姜", "姒", "妫", "嬴", "姞", "妘", "姚"]

# 西周士的职业
const SHI_PROFESSIONS = [
	{"id": "邑宰", "name": "邑宰/家臣", "desc": "为卿大夫管理采邑，有稳定俸禄", "income": "俸禄（谷物/采邑）"},
	{"id": "武士", "name": "武士/甲士", "desc": "乘战车作战的贵族战士", "income": "军饷+战利品"},
	{"id": "小吏", "name": "小吏", "desc": "在官府中担任文书、书记等职", "income": "官俸"},
	{"id": "门客", "name": "门客/宾客", "desc": "寄身于诸侯或卿大夫门下出谋划策", "income": "食宿+赏赐"},
	{"id": "教师", "name": "教师", "desc": "教授六艺（礼乐射御书数）", "income": "束脩（学生馈赠）"},
	{"id": "巫祝", "name": "巫/祝/卜", "desc": "主持祭祀、占卜吉凶", "income": "祭祀赏赐"},
	{"id": "游士", "name": "游士", "desc": "周游列国寻求出仕机会的学者", "income": "不固定（推荐+赏赐）"},
]

# ============================================================
# 角色创建
# ============================================================
func create_character(options: Dictionary) -> Dictionary:
	var character = {
		"id": "char_%d" % Time.get_unix_time_from_system(),
		"name": options.get("name", "无名氏"),
		"surname": options.get("surname", "姬"),       # 姓——永不变
		"clan": options.get("clan", ""),                # 氏——可改变
		"ethnicity": DynastyManager.get_ethnicity(),    # 民族——永不变
		"gender": options.get("gender", "male"),  # 默认男性；后世朝代可扩展
		"birth_year": GameState.current_year - options.get("age", 0),
		"age": options.get("age", 0),
		"is_alive": true,
		"social_class": options.get("social_class", "士"),
		"social_level": options.get("social_level", 3),
		"profession": options.get("profession", "小吏"),
		"attributes": _generate_attributes(options.get("attr_bonus", {})),
		"derived": {},
		"skills": options.get("skills", ["礼法:1", "书数:1"]),
		"inventory": [],
		"relationships": {"spouse": null, "children": [], "rivals": [], "allies": []},
		"status_flags": [],
		"reputation": 0,
		"wealth": options.get("starting_wealth", 30 + randi_range(0, 60)),
		"ambition": 20,
		"legitimacy": 0,
		"official_position": "",     # 官职——空表示无官职
		"fief": "",                # 封地——诸侯才有
		"household_troops": {"步兵": 0, "车兵": 0, "王师": 0},  # 按兵种存储
		"max_troops": {},          # 从TROOP_LIMITS计算（按兵种）
	}

	# 计算衍生属性
	character.derived = _calculate_derived(character)

	# 保存到全局状态
	GameState.current_character = character
	GameState.family_data.surname = character.surname
	GameState.family_data.clan = character.clan
	GameState.family_data.wealth = character.wealth

	return character

func _generate_attributes(bonus: Dictionary) -> Dictionary:
	# 投3d6决定每个属性（产生3-18的分布，均值10.5）
	var attrs = {}
	for attr in BASE_ATTRIBUTES:
		var roll = randi_range(1, 6) + randi_range(1, 6) + randi_range(1, 6)
		roll += bonus.get(attr, 0)
		attrs[attr] = clampi(roll, 3, 20)
	return attrs

func _calculate_derived(character: Dictionary) -> Dictionary:
	var attrs = character.attributes
	return {
		"health": clampi(attrs.con * 5 + 30, 10, 100),
		"reputation": character.reputation,
		"power": _calculate_power(character),
		"ambition": character.ambition,
		"legitimacy": character.legitimacy,
	}

func _calculate_power(character: Dictionary) -> int:
	var attrs = character.attributes
	var base = (attrs.str + attrs.cha) / 2
	base += character.reputation / 4
	base += character.wealth / 30
	# 家兵势力贡献（多兵种）
	var troops = character.get("household_troops", {})
	if troops is int:  # 旧档兼容
		base += troops / 50
	else:
		for ttype in troops:
			var tdata = TROOP_TYPES.get(ttype, {})
			base += troops[ttype] * tdata.get("power_per_50", 0) / 50
	return clampi(int(base), 0, 100)

# ============================================================
# 职业履职
# ============================================================
const PROFESSION_WORK_DATA = {
	"邑宰": {"attr": "int", "income": 30, "desc": "管理采邑事务，征收赋税，调解纠纷", "critical_bonus": "skill_礼法:1"},
	"武士": {"attr": "str", "income": 25, "desc": "在演武场训练，巡逻边境，磨砺武艺", "critical_bonus": "skill_射御:1"},
	"小吏": {"attr": "int", "income": 20, "desc": "在官府中抄写文书，整理档案，处理杂务", "critical_bonus": "skill_书数:1"},
	"门客": {"attr": "cha", "income": 15, "desc": "为卿大夫出谋划策，陪侍左右", "critical_bonus": "skill_游说:1"},
	"教师": {"attr": "int", "income": 15, "desc": "教授学子六艺，批改功课", "critical_bonus": "skill_礼法:1"},
	"巫祝": {"attr": "vir", "income": 20, "desc": "主持祭祀仪式，占卜吉凶，解读天象", "critical_bonus": "skill_乐:1"},
	"游士": {"attr": "cha", "income": 15, "desc": "周游列国，拜会权贵，寻求出仕机会", "critical_bonus": "skill_游说:1"},
}

func get_profession_work_attr(profession_id: String) -> String:
	return PROFESSION_WORK_DATA.get(profession_id, {}).get("attr", "luk")

func get_profession_income(profession_id: String) -> int:
	return PROFESSION_WORK_DATA.get(profession_id, {}).get("income", 10)

func get_profession_work_desc(profession_id: String) -> String:
	return PROFESSION_WORK_DATA.get(profession_id, {}).get("desc", "处理日常事务")

func get_profession_critical_bonus(profession_id: String) -> String:
	return PROFESSION_WORK_DATA.get(profession_id, {}).get("critical_bonus", "")

func get_level_net_income(social_level: int) -> Dictionary:
	"""返回 {stipend, expenses, net} 每季俸禄信息"""
	var stipend = LEVEL_STIPEND.get(social_level, 0)
	var expenses = LEVEL_EXPENSES.get(social_level, 0)
	return {"stipend": stipend, "expenses": expenses, "net": stipend - expenses}

# ============================================================
# 技能修习
# ============================================================
func study_skill(character: Dictionary, skill_name: String, intensity: int = 1) -> Dictionary:
	# intensity = 学习强度（大成功=2, 成功=1, 失败=0）
	if intensity <= 0:
		return {"success": false, "message": "修习无果，白白浪费了时间。"}

	# 查找当前技能等级
	var current_level = 0
	var skill_index = -1
	for i in range(character.skills.size()):
		if character.skills[i].begins_with(skill_name + ":"):
			current_level = int(character.skills[i].split(":")[1])
			skill_index = i
			break

	if current_level >= 5:
		return {"success": false, "message": "%s已达最高等级（5级），无法继续提升。" % skill_name}

	var new_level = mini(current_level + intensity, 5)
	add_skill(character, skill_name, intensity)
	return {
		"success": true,
		"skill": skill_name,
		"old_level": current_level,
		"new_level": new_level,
		"message": "%s从%d级提升至%d级！" % [skill_name, current_level, new_level]
	}

# ============================================================
# 属性查询
# ============================================================
func get_attr(character: Dictionary, attr_name: String) -> int:
	return character.get("attributes", {}).get(attr_name, 10)

func get_attr_display(attr_name: String) -> String:
	return ATTR_NAMES.get(attr_name, attr_name)

func get_attr_bonus(character: Dictionary, attr_name: String) -> int:
	return DiceSystem.attr_to_bonus(get_attr(character, attr_name))

func get_social_display(character: Dictionary) -> String:
	var level = character.get("social_level", 3)
	return SOCIAL_CLASSES.get(level, {}).get("display", "士")

# ============================================================
# 角色更新
# ============================================================
func modify_health(character: Dictionary, delta: int) -> void:
	character.derived.health = clampi(character.derived.health + delta, 0, 100)

func modify_reputation(character: Dictionary, delta: int) -> void:
	character.reputation += delta
	character.derived.reputation = character.reputation

func modify_wealth(delta: int) -> void:
	GameState.family_data.wealth = max(0, GameState.family_data.wealth + delta)

func modify_ambition(character: Dictionary, delta: int) -> void:
	var lvl = character.get("social_level", 3)
	var cap: int
	match lvl:
		1: cap = 30   # 奴隶——求生存，无意宏图
		2: cap = 50   # 庶人——安于温饱
		3: cap = 70   # 士——胸怀志向，但有限度
		4: cap = 85   # 卿大夫——权柄在握，野心膨胀
		5: cap = 95   # 诸侯——封疆裂土，觊觎王权
		_: cap = 100  # 天子——天下共主，野心无界
	character.ambition = clampi(character.ambition + delta, 0, cap)
	character.derived.ambition = character.ambition

func modify_attribute(character: Dictionary, attr_name: String, delta: int) -> void:
	character.attributes[attr_name] = clampi(character.attributes.get(attr_name, 10) + delta, 3, 20)
	character.derived = _calculate_derived(character)

func add_skill(character: Dictionary, skill_name: String, level: int = 1) -> void:
	# 检查是否已有此技能
	for i in range(character.skills.size()):
		if character.skills[i].begins_with(skill_name + ":"):
			var current_level = int(character.skills[i].split(":")[1])
			var new_level = mini(current_level + level, 5)
			character.skills[i] = skill_name + ":" + str(new_level)
			return
	# 新技能
	character.skills.append(skill_name + ":" + str(level))

# ============================================================
# 年龄阶段
# ============================================================
func get_character_age(character: Dictionary) -> int:
	return GameState.current_year - character.birth_year

func update_character_age(character: Dictionary) -> void:
	character.age = get_character_age(character)

# ============================================================
# 身份跃迁检查
# ============================================================
func can_promote(character: Dictionary) -> bool:
	var current_level = character.social_level

	# 天子之上不可再升
	if current_level >= 6:
		return false

	var rep = character.derived.get("reputation", 0)
	var power = character.derived.power
	match current_level:
		1: return rep >= 40              # 奴隶→庶人：仅声望
		2: return rep >= 70              # 庶人→士：仅声望
		3: return rep >= 90              # 士→卿大夫：仅声望（还需官职）
		4: return power >= 70 or rep >= 120  # 卿大夫→诸侯
		5: return power >= 85 or rep >= 150  # 诸侯→天子
	return false

func can_promote_by_reputation(character: Dictionary) -> bool:
	"""仅通过声望检查是否可以晋升"""
	var current_level = character.social_level
	if current_level >= 6:
		return false
	var rep = character.derived.get("reputation", 0)
	match current_level:
		1: return rep >= 40
		2: return rep >= 70
		3: return rep >= 90
		4: return rep >= 120
		5: return rep >= 150
	return false

func can_promote_to_qingdafu(character: Dictionary) -> bool:
	"""士→卿大夫：除了声望，还必须持有官职"""
	if character.social_level != 3:
		return false
	if character.derived.get("reputation", 0) < 90:
		return false
	var pos = character.get("official_position", "")
	return not pos.is_empty()

func promote_character(character: Dictionary) -> Dictionary:
	if not can_promote(character):
		return {"success": false, "message": "条件不满足，无法跃迁"}

	var old_level = character.social_level
	character.social_level = old_level + 1
	character.social_class = SOCIAL_CLASSES[character.social_level].name

	# 晋升诸侯——分配封地
	if character.social_level == 5:
		var birth = character.get("birth_state", "")
		if birth == "周王畿" or birth.is_empty():
			# 王畿卿大夫受封外地
			character["fief"] = FEUDAL_STATES[randi_range(0, FEUDAL_STATES.size() - 1)]
		else:
			# 回乡就封
			character["fief"] = birth

	# 晋升——授予初始家兵/更新上限
	if character.social_level >= 4 and old_level < 4:
		character.max_troops = TROOP_LIMITS.get(character.social_level, {})
		character.household_troops = {"步兵": 30 + randi_range(0, 40), "车兵": 0, "王师": 0}
	elif character.social_level > old_level and character.social_level >= 4:
		character.max_troops = TROOP_LIMITS.get(character.social_level, {})
		# 确保新兵种键存在
		var troops = character.get("household_troops", {})
		if troops is int:
			troops = {"步兵": troops, "车兵": 0, "王师": 0}
		for key in character.max_troops:
			if not troops.has(key):
				troops[key] = 0
		character.household_troops = troops

	# 晋升后衰减：百分比（新环境中你只是"小人物"）
	var ambition_pct := randf_range(0.20, 0.40)   # 减当前野心的20%-40%
	var rep_pct := randf_range(0.15, 0.30)        # 减当前声望的15%-30%
	var ambition_loss := int(ceil(character.ambition * ambition_pct))
	var rep_loss := int(ceil(character.reputation * rep_pct))
	character.ambition = max(0, character.ambition - ambition_loss)
	character.reputation = max(0, character.reputation - rep_loss)
	character.derived.ambition = character.ambition
	character.derived.reputation = character.reputation
	# 重新计算势力值（声望变了）
	character.derived.power = _calculate_power(character)

	var decay_msg := "\n（晋升衰减：野心-%.0f%%，声望-%.0f%%）" % [ambition_pct * 100, rep_pct * 100]

	# 重置声望停滞跟踪（新等级，新起点）
	GameState.reputation_stall_seasons = 0
	GameState.last_stall_check_rep = character.derived.get("reputation", 0)
	return {
		"success": true,
		"old_level": old_level,
		"new_level": character.social_level,
		"new_class": character.social_class,
		"ambition_loss": ambition_loss,
		"rep_loss": rep_loss,
		"message": "从%s跃升至%s！%s" % [
			SOCIAL_CLASSES[old_level].display,
			SOCIAL_CLASSES[character.social_level].display,
			decay_msg
		]
	}

func demote_character(character: Dictionary, target_level: int = 2) -> Dictionary:
	var old_level: int = character.social_level
	if target_level >= old_level:
		return {"success": false, "message": "目标等级不低于当前等级，无法降级"}
	character.social_level = target_level
	character.social_class = SOCIAL_CLASSES[target_level].name
	character.profession = "无业"
	# 贬为庶人或以下→家兵解散
	if target_level <= 2:
		character.household_troops = {"步兵": 0, "车兵": 0, "王师": 0}
		character.max_troops = {}
	return {
		"success": true,
		"old_level": old_level,
		"new_level": target_level,
		"new_class": character.social_class,
		"message": "从%s贬为%s！" % [
			SOCIAL_CLASSES[old_level].display,
			SOCIAL_CLASSES[target_level].display
		]
	}

# 声望停滞检测（每季调用）
func check_reputation_stall(character: Dictionary) -> Dictionary:
	"""检测声望停滞状况。卿大夫及以上生效。返回 {stalled, seasons, consequence, message}"""
	var level = character.social_level
	if level < 4:
		return {"stalled": false, "seasons": 0, "consequence": "", "message": ""}

	var current_rep = character.derived.get("reputation", 0)
	var last_rep = GameState.last_stall_check_rep

	if current_rep > last_rep:
		# 声望有增长——重置计数器
		GameState.reputation_stall_seasons = 0
		GameState.last_stall_check_rep = current_rep
		return {"stalled": false, "seasons": 0, "consequence": "", "message": ""}

	# 声望未增长
	GameState.reputation_stall_seasons += 1
	GameState.last_stall_check_rep = current_rep
	var seasons = GameState.reputation_stall_seasons

	var result = {"stalled": true, "seasons": seasons, "consequence": "", "message": ""}

	match seasons:
		4:  # 1年——警告
			result.consequence = "warn"
			result.message = "⚠ 久居高位而无建树，朝野已有微词……"
		8:  # 2年——惩罚
			result.consequence = "penalty"
			result.message = "⚠ 同僚暗中议论——你德不配位，声望-10。"
			modify_reputation(character, -10)
		12: # 3年——降级（实际降级在 hud.gd 中执行）
			result.consequence = "demote"
			result.message = "📉 天下人皆言你德不配位……"

	return result

# ============================================================
# 家兵招募
# ============================================================
func recruit_troops(character: Dictionary, amount: int, troop_type: String = "步兵") -> Dictionary:
	"""招募家兵。按兵种区分花费和上限。"""
	var max_troops = character.get("max_troops", {})
	if max_troops.is_empty():
		return {"success": false, "message": "你尚无养兵之权——至少需位列卿大夫。"}

	var tdata = TROOP_TYPES.get(troop_type, {})
	if tdata.is_empty():
		return {"success": false, "message": "未知兵种：%s" % troop_type}

	var type_limit = max_troops.get(troop_type, 0)
	if type_limit <= 0:
		return {"success": false, "message": "你当前等级无法招募%s。" % troop_type}

	var troops = character.get("household_troops", {})
	if troops is int:
		troops = {"步兵": troops, "车兵": 0, "王师": 0}

	var current = troops.get(troop_type, 0)
	if current >= type_limit:
		return {"success": false, "message": "%s已达上限（%d人），无法再募。" % [troop_type, type_limit]}

	var cost_per = tdata.get("cost", 2)
	var actual = mini(amount, type_limit - current)
	var total_cost = actual * cost_per
	var wealth = GameState.family_data.get("wealth", 0)
	if wealth < total_cost:
		actual = wealth / cost_per
		total_cost = actual * cost_per
		if actual <= 0:
			return {"success": false, "message": "钱财不足，无力募兵。（%s每人需%d石）" % [troop_type, cost_per]}

	troops[troop_type] = current + actual
	character["household_troops"] = troops
	modify_wealth(-total_cost)

	# 计算总兵力
	var total_count = 0
	for t in troops:
		total_count += troops[t]

	return {
		"success": true,
		"recruited": actual,
		"cost": total_cost,
		"troop_type": troop_type,
		"new_total": troops[troop_type],
		"type_limit": type_limit,
		"message": "招募了%d名%s，花费%d石。（%s现有%d/%d人，总兵力%d人）" % [actual, troop_type, total_cost, troop_type, troops[troop_type], type_limit, total_count]
	}

# ============================================================
# 婚姻系统（西周：同姓不婚）
# ============================================================
func is_married(character: Dictionary) -> bool:
	var spouse = character.relationships.get("spouse", null)
	return spouse != null and not (spouse is Dictionary and spouse.is_empty())

func get_eligible_surnames(character: Dictionary) -> Array:
	var eligible = []
	for s in EIGHT_SURNAMES:
		if s != character.surname:
			eligible.append(s)
	return eligible

func generate_spouse(surname: String, clan: String, age: int) -> Dictionary:
	var names_f = ["姬姜", "淑姬", "仲姜", "孟任", "季芈", "伯嬴", "叔妫", "少姚"]
	var names_m = ["伯同", "仲行", "叔达", "季友", "子服", "公孙", "梁仲", "华父"]
	var gender = "female" if randf() < 0.5 else "male"
	var pool = names_f if gender == "female" else names_m
	return {
		"name": pool[randi_range(0, pool.size() - 1)],
		"surname": surname, "clan": clan, "gender": gender,
		"age": age, "birth_year": GameState.current_year - age, "attributes": _generate_attributes({}),
		"relation": "spouse",
		"loyalty": 70 + randi_range(0, 20),
		"last_affair_year": -9999,
		"is_pregnant": false,
		"pregnancy_remaining": 0
	}

func propose_marriage(character: Dictionary, spouse_surname: String, spouse_clan: String, dowry: int) -> Dictionary:
	if is_married(character):
		return {"success": false, "message": "你已有配偶。西周礼法不允许多妻。"}
	if spouse_surname == character.surname:
		return {"success": false, "message": "同姓不婚！%s姓与%s姓不可通婚。" % [spouse_surname, character.surname]}
	if GameState.family_data.wealth < dowry:
		return {"success": false, "message": "聘礼不足！需要 %d 石，你只有 %d 石。" % [dowry, GameState.family_data.wealth]}
	CharacterManager.modify_wealth(-dowry)
	var spouse_age = max(16, character.age - randi_range(-3, 8))
	var spouse = generate_spouse(spouse_surname, spouse_clan, spouse_age)
	var bride_wealth = max(10, dowry - 20 + randi_range(0, 20))
	CharacterManager.modify_wealth(bride_wealth)
	character.relationships.spouse = spouse
	spouse["married_year"] = GameState.current_year
	GameState.family_data.family_tree["spouse"] = spouse
	# 诸侯娶妻——自动生成媵妾（随嫁姊妹/宗女）
	var ying_msg = ""
	if character.social_level >= 5:
		var ying_limits = SPOUSE_LIMITS.get(character.social_level, {}).get("ying_qie", 0)
		if ying_limits > 0:
			var ying_count = mini(ying_limits, 1 + randi_range(0, 2))  # 随机1-3位媵妾
			if not GameState.family_data.has("ying_qie"):
				GameState.family_data["ying_qie"] = []
			for _yi in range(ying_count):
				var ying = generate_spouse(spouse_surname, spouse_clan, max(14, spouse.age - randi_range(-2, 2)))
				ying["married_year"] = GameState.current_year
				ying["is_pregnant"] = false
				ying["pregnancy_remaining"] = 0
				ying["loyalty"] = 65 + randi_range(0, 20)
				ying["last_affair_year"] = -9999
				GameState.family_data.ying_qie.append(ying)
			ying_msg = " 随嫁媵妾%d人——皆%s姓宗女。" % [ying_count, spouse_surname]
	return {
		"success": true, "spouse": spouse, "dowry_paid": dowry, "bride_wealth": bride_wealth,
		"message": "你与%s%s·%s氏结为夫妻！嫁妆 %d 石。%s" % [spouse_surname, spouse.name, spouse.clan, bride_wealth, ying_msg]
	}

func propose_marriage_parents(character: Dictionary, spouse_surname: String, spouse_clan: String) -> Dictionary:
	if is_married(character):
		return {"success": false, "message": "你已有配偶。"}
	if spouse_surname == character.surname:
		return {"success": false, "message": "同姓不婚！"}
	var spouse_age = max(16, character.age - randi_range(-3, 8))
	var spouse = generate_spouse(spouse_surname, spouse_clan, spouse_age)
	var bride_wealth = 10 + randi_range(5, 20)
	CharacterManager.modify_wealth(bride_wealth)
	character.relationships.spouse = spouse
	spouse["married_year"] = GameState.current_year
	GameState.family_data.family_tree["spouse"] = spouse
	# 诸侯娶妻——自动生成媵妾
	var ying_msg = ""
	if character.social_level >= 5:
		var ying_limits = SPOUSE_LIMITS.get(character.social_level, {}).get("ying_qie", 0)
		if ying_limits > 0:
			var ying_count = mini(ying_limits, 1 + randi_range(0, 2))
			if not GameState.family_data.has("ying_qie"):
				GameState.family_data["ying_qie"] = []
			for _yi in range(ying_count):
				var ying = generate_spouse(spouse_surname, spouse_clan, max(14, spouse.age - randi_range(-2, 2)))
				ying["married_year"] = GameState.current_year
				ying["is_pregnant"] = false
				ying["pregnancy_remaining"] = 0
				ying["loyalty"] = 65 + randi_range(0, 20)
				ying["last_affair_year"] = -9999
				GameState.family_data.ying_qie.append(ying)
			ying_msg = " 随嫁媵妾%d人——皆%s姓宗女。" % [ying_count, spouse_surname]
	return {
		"success": true, "spouse": spouse, "dowry_paid": 0, "bride_wealth": bride_wealth,
		"message": "父母之命——你与%s%s·%s氏结为夫妻！嫁妆 %d 石。%s" % [spouse_surname, spouse.name, spouse.clan, bride_wealth, ying_msg]
	}

# ============================================================
# 子女系统
# ============================================================
func get_character_children(character: Dictionary) -> Array:
	return character.relationships.get("children", [])

func try_birth(character: Dictionary) -> Dictionary:
	"""被动生育已废弃——改用怀孕系统。"""
	return {}

func start_pregnancy(mother_type: String, mother_index: int = 0) -> Dictionary:
	"""开始怀孕。mother_type: 'wife' / 'concubine' / 'tongfang'。返回包含fertility信息。"""
	var char = GameState.current_character
	var fertility = FERTILITY_RATES.get(mother_type, 10.0)
	var cha_bonus = DiceSystem.attr_to_bonus(char.attributes.get("cha", 10))
	# CHA加成：每点加2%
	fertility += cha_bonus * 2.0
	# 年龄衰减：30岁后每岁-1%
	var age = get_character_age(char)
	if age > 30:
		fertility = max(2.0, fertility - (age - 30) * 1.0)
	# 掷骰判定是否受孕
	if randf() * 100.0 > fertility:
		var hint = ""
		match mother_type:
			"wife": hint = "妻子"
			"concubine": hint = "妾室"
			"tongfang": hint = "通房丫头"
		return {"success": true, "pregnant": false, "fertility": fertility,
			"message": "%s%s此次未能受孕。（受孕率%.0f%%）" % [hint, _get_mother_name(mother_type, mother_index), fertility]}
	if mother_type == "wife":
		if not is_married(char):
			return {"success": false, "message": "你尚未娶妻。"}
		var spouse = char.relationships.get("spouse", {})
		if spouse.get("is_pregnant", false):
			return {"success": false, "message": "妻子已有身孕，不必急于求子。"}
		spouse["is_pregnant"] = true
		spouse["pregnancy_remaining"] = 3
		add_household_event("pregnancy", "正妻" + spouse.get("name", "") + "有孕")
		return {"success": true, "pregnant": true, "fertility": fertility,
			"message": "妻子%s有了身孕——怀胎九月，静待佳音。" % spouse.get("name", "")}
	elif mother_type == "concubine":
		var concubines = GameState.family_data.get("concubines", [])
		if mother_index < 0 or mother_index >= concubines.size():
			return {"success": false, "message": "无效的妾室。"}
		var cn = concubines[mother_index]
		if cn.get("is_pregnant", false):
			return {"success": false, "message": "妾室已有身孕。"}
		cn["is_pregnant"] = true
		cn["pregnancy_remaining"] = 3
		add_household_event("pregnancy", "妾室" + cn.get("name", "") + "有孕")
		return {"success": true, "pregnant": true, "fertility": fertility,
			"message": "妾室%s有了身孕——怀胎九月，静待佳音。" % cn.get("name", "")}
	elif mother_type == "tongfang":
		var tongfangs = GameState.family_data.get("tongfangs", [])
		if mother_index < 0 or mother_index >= tongfangs.size():
			return {"success": false, "message": "无效的通房丫头。"}
		var tf = tongfangs[mother_index]
		if tf.get("is_pregnant", false):
			return {"success": false, "message": "通房丫头已有身孕。"}
		tf["is_pregnant"] = true
		tf["pregnancy_remaining"] = 3
		add_household_event("pregnancy", "通房" + tf.get("name", "") + "有孕")
		return {"success": true, "pregnant": true, "fertility": fertility,
			"message": "通房丫头%s有了身孕。" % tf.get("name", "")}
	elif mother_type == "furen":
		var furens = GameState.family_data.get("furens", [])
		if mother_index < 0 or mother_index >= furens.size():
			return {"success": false, "message": "无效的夫人。"}
		var fr = furens[mother_index]
		if fr.get("is_pregnant", false):
			return {"success": false, "message": "夫人已有身孕。"}
		fr["is_pregnant"] = true
		fr["pregnancy_remaining"] = 3
		add_household_event("pregnancy", "夫人" + fr.get("name", "") + "有孕")
		return {"success": true, "pregnant": true, "fertility": fertility,
			"message": "夫人%s有了身孕——天子血脉，尊贵非凡。" % fr.get("name", "")}
	elif mother_type == "ying_qie":
		var ying_qie = GameState.family_data.get("ying_qie", [])
		if mother_index < 0 or mother_index >= ying_qie.size():
			return {"success": false, "message": "无效的媵妾。"}
		var yq = ying_qie[mother_index]
		if yq.get("is_pregnant", false):
			return {"success": false, "message": "媵妾已有身孕。"}
		yq["is_pregnant"] = true
		yq["pregnancy_remaining"] = 3
		add_household_event("pregnancy", "媵妾" + yq.get("name", "") + "有孕")
		return {"success": true, "pregnant": true, "fertility": fertility,
			"message": "媵妾%s有了身孕——诸侯血脉，%s。" % [yq.get("name", ""), "喜添贵子"]}
	return {"success": false, "message": "未知的母亲类型：%s" % mother_type}

func _get_mother_name(mother_type: String, mother_index: int) -> String:
	"""获取母亲名称（辅助函数）"""
	var char = GameState.current_character
	match mother_type:
		"wife":
			var sp = char.relationships.get("spouse", {})
			return sp.get("name", "")
		"concubine":
			var concubines = GameState.family_data.get("concubines", [])
			if mother_index >= 0 and mother_index < concubines.size():
				return concubines[mother_index].get("name", "")
		"tongfang":
			var tongfangs = GameState.family_data.get("tongfangs", [])
			if mother_index >= 0 and mother_index < tongfangs.size():
				return tongfangs[mother_index].get("name", "")
		"furen":
			var furens = GameState.family_data.get("furens", [])
			if mother_index >= 0 and mother_index < furens.size():
				return furens[mother_index].get("name", "")
		"ying_qie":
			var ying_qie = GameState.family_data.get("ying_qie", [])
			if mother_index >= 0 and mother_index < ying_qie.size():
				return ying_qie[mother_index].get("name", "")
	return ""

func process_pregnancies(character: Dictionary) -> Array:
	"""每季推进孕期，分娩时触发。返回通知数组。"""
	var notices: Array = []
	# 正妻
	if is_married(character):
		var spouse = character.relationships.get("spouse", {})
		if spouse.get("is_pregnant", false):
			spouse["pregnancy_remaining"] = spouse.get("pregnancy_remaining", 3) - 1
			if spouse.pregnancy_remaining <= 0:
				spouse["is_pregnant"] = false
				spouse["pregnancy_remaining"] = 0
				var children = character.relationships.get("children", [])
				var child = generate_child(character, "wife", 0)
				children.append(child)
				character.relationships.children = children
				if not GameState.family_data.family_tree.has("children"):
					GameState.family_data.family_tree["children"] = []
				GameState.family_data.family_tree.children.append(child)
				notices.append("👶 喜得%s——%s%s！" % ["千金" if child.gender == "female" else "贵子", child.surname, child.name])
				add_household_event("birth", "正妻诞下" + ("嫡女" if child.gender == "female" else "嫡子") + child.name)
	# 妾室
	var concubines = GameState.family_data.get("concubines", [])
	for i in range(concubines.size()):
		var cn = concubines[i]
		if cn.get("is_pregnant", false):
			cn["pregnancy_remaining"] = cn.get("pregnancy_remaining", 3) - 1
			if cn.pregnancy_remaining <= 0:
				cn["is_pregnant"] = false
				cn["pregnancy_remaining"] = 0
				var children = character.relationships.get("children", [])
				var child = generate_child(character, "concubine", i)
				children.append(child)
				character.relationships.children = children
				if not GameState.family_data.family_tree.has("children"):
					GameState.family_data.family_tree["children"] = []
				GameState.family_data.family_tree.children.append(child)
				var mom_name = cn.get("name", "")
				notices.append("👶 妾室%s喜得%s——%s%s（庶出）！" % [mom_name, "千金" if child.gender == "female" else "贵子", child.surname, child.name])
				add_household_event("birth", "妾室" + mom_name + "诞下庶出子女")
	# 通房丫头
	var tongfangs = GameState.family_data.get("tongfangs", [])
	for i in range(tongfangs.size()):
		var tf = tongfangs[i]
		if tf.get("is_pregnant", false):
			tf["pregnancy_remaining"] = tf.get("pregnancy_remaining", 3) - 1
			if tf.pregnancy_remaining <= 0:
				tf["is_pregnant"] = false
				tf["pregnancy_remaining"] = 0
				var children = character.relationships.get("children", [])
				var child = generate_child(character, "tongfang", i)
				children.append(child)
				character.relationships.children = children
				if not GameState.family_data.family_tree.has("children"):
					GameState.family_data.family_tree["children"] = []
				GameState.family_data.family_tree.children.append(child)
				var mom_name = tf.get("name", "")
				notices.append("👶 通房丫头%s喜得%s——%s%s（婢生）！" % [mom_name, "千金" if child.gender == "female" else "贵子", child.surname, child.name])
				add_household_event("birth", "通房" + mom_name + "诞下婢生子")
	# 夫人（天子专属）
	var furens = GameState.family_data.get("furens", [])
	for i in range(furens.size()):
		var fr = furens[i]
		if fr.get("is_pregnant", false):
			fr["pregnancy_remaining"] = fr.get("pregnancy_remaining", 3) - 1
			if fr.pregnancy_remaining <= 0:
				fr["is_pregnant"] = false
				fr["pregnancy_remaining"] = 0
				var children = character.relationships.get("children", [])
				var child = generate_child(character, "furen", i)
				children.append(child)
				character.relationships.children = children
				if not GameState.family_data.family_tree.has("children"):
					GameState.family_data.family_tree["children"] = []
				GameState.family_data.family_tree.children.append(child)
				var mom_name = fr.get("name", "")
				notices.append("👑 夫人%s喜得%s——%s%s（贵子）！" % [mom_name, "千金" if child.gender == "female" else "贵子", child.surname, child.name])
				add_household_event("birth", "夫人" + mom_name + "诞下贵子")
	# 媵妾（诸侯专属）
	var ying_qie = GameState.family_data.get("ying_qie", [])
	for i in range(ying_qie.size()):
		var yq = ying_qie[i]
		if yq.get("is_pregnant", false):
			yq["pregnancy_remaining"] = yq.get("pregnancy_remaining", 3) - 1
			if yq.pregnancy_remaining <= 0:
				yq["is_pregnant"] = false
				yq["pregnancy_remaining"] = 0
				var children = character.relationships.get("children", [])
				var child = generate_child(character, "ying_qie", i)
				children.append(child)
				character.relationships.children = children
				if not GameState.family_data.family_tree.has("children"):
					GameState.family_data.family_tree["children"] = []
				GameState.family_data.family_tree.children.append(child)
				var mom_name = yq.get("name", "")
				notices.append("🏰 媵妾%s喜得%s——%s%s（媵出）！" % [mom_name, "千金" if child.gender == "female" else "贵子", child.surname, child.name])
				add_household_event("birth", "媵妾" + mom_name + "诞下媵出子女")
	return notices

func generate_child(character: Dictionary, mother_type: String = "wife", mother_index: int = 0) -> Dictionary:
	"""生成子女。mother_type: 'wife'=嫡出, 'concubine'=庶出, 'tongfang'=婢生"""
	var gender = "male" if randf() < 0.5 else "female"
	var male_names = ["伯禽", "仲山", "叔向", "季札", "子产", "子思", "无忌", "去疾", "无恤", "展禽"]
	var female_names = ["仲姜", "季嬴", "孟任", "叔姬", "伯芈", "少姚", "淑姬", "惠姜"]
	var pool = male_names if gender == "male" else female_names
	var name = pool[randi_range(0, pool.size() - 1)]
	# 母方属性（不同身份影响属性浮动范围）
	var mother_attrs = {}
	var attr_variance = 3  # 嫡出浮动±3
	if mother_type == "wife":
		var spouse = character.relationships.get("spouse", {})
		mother_attrs = spouse.get("attributes", {})
		attr_variance = 3
	elif mother_type == "concubine":
		var concubines = GameState.family_data.get("concubines", [])
		if mother_index >= 0 and mother_index < concubines.size():
			mother_attrs = concubines[mother_index].get("attributes", {})
		attr_variance = 4
	elif mother_type == "tongfang":
		var tongfangs = GameState.family_data.get("tongfangs", [])
		if mother_index >= 0 and mother_index < tongfangs.size():
			mother_attrs = tongfangs[mother_index].get("attributes", {})
		attr_variance = 5
	# 夫人——天子后宫，属性略优
	if mother_type == "furen":
		var furens = GameState.family_data.get("furens", [])
		if mother_index >= 0 and mother_index < furens.size():
			mother_attrs = furens[mother_index].get("attributes", {})
		attr_variance = 3
	# 媵妾——诸侯侧室
	if mother_type == "ying_qie":
		var ying_qie = GameState.family_data.get("ying_qie", [])
		if mother_index >= 0 and mother_index < ying_qie.size():
			mother_attrs = ying_qie[mother_index].get("attributes", {})
		attr_variance = 4
	var father_attrs = character.get("attributes", {})
	var attrs = {}
	for key in ["con", "int", "str", "cha", "vir", "luk"]:
		var f_val = father_attrs.get(key, 10)
		var m_val = mother_attrs.get(key, 10)
		attrs[key] = clampi(int((f_val + m_val) / 2.0) + randi_range(-attr_variance, attr_variance), 3, 20)
	# 计算同母出生序
	var existing = character.relationships.get("children", [])
	var birth_order = 1
	for c in existing:
		if c.get("mother_type", "") == mother_type and c.get("mother_index", -1) == mother_index:
			birth_order += 1
	return {
		"name": name,
		"surname": character.get("surname", ""),
		"gender": gender,
		"birth_year": GameState.current_year,
		"age": 0,
		"attributes": attrs,
		"is_alive": true,
		"mother_type": mother_type,
		"mother_index": mother_index,
		"birth_order": birth_order,
		"education_focus": "",
		"education_progress": 0,
		"is_heir": false,
		"is_separated": false,
	}

func test_spouse_loyalty(character: Dictionary) -> Dictionary:
	"""考察妻子忠诚度。返回 {loyalty: int, assessment: str, message: str}"""
	var spouse = character.relationships.get("spouse", {})
	if spouse.is_empty():
		return {"loyalty": 0, "assessment": "none", "message": "你尚未娶妻。"}
	var loyalty = spouse.get("loyalty", 80)
	var years_married = GameState.current_year - spouse.get("married_year", GameState.current_year)
	# INT掷骰——判断忠诚度
	var int_bonus = DiceSystem.attr_to_bonus(character.attributes.get("int", 10))
	var roll = DiceSystem.roll_dice("2d6", int_bonus, 0)
	var tier = roll.get("tier", 2)
	var assessment = ""
	var msg = ""
	# 根据INT掷骰结果给出不同精度的评估
	var accuracy = 0  # 0=精确 1=略有偏差 2=模糊
	match tier:
		0: accuracy = 0  # 大成功——精确判断
		1: accuracy = 0
		2: accuracy = 1  # 部分成功——略有偏差
		3: accuracy = 2  # 失败——难以判断
	var reported_loyalty = loyalty
	if accuracy == 1:
		reported_loyalty = loyalty + randi_range(-15, 15)
	elif accuracy == 2:
		reported_loyalty = loyalty + randi_range(-30, 30)
	reported_loyalty = clampi(reported_loyalty, 0, 100)
	if reported_loyalty >= 80:
		assessment = "坚贞不渝"; msg = "妻子对你忠贞不二（忠诚度约%d）。" % reported_loyalty
	elif reported_loyalty >= 60:
		assessment = "尚算安稳"; msg = "妻子还算安分（忠诚度约%d）。" % reported_loyalty
	elif reported_loyalty >= 40:
		assessment = "略有微词"; msg = "妻子似有不满（忠诚度约%d）。" % reported_loyalty
	elif reported_loyalty >= 20:
		assessment = "心有他属"; msg = "妻子心思恐已不在家中（忠诚度约%d）……" % reported_loyalty
	else:
		assessment = "貌合神离"; msg = "妻子恐已心生离意（忠诚度约%d）！" % reported_loyalty
	if accuracy > 0:
		msg += "（你不敢完全确定。）"
	return {"loyalty": reported_loyalty, "assessment": assessment, "message": msg, "accuracy": accuracy}

func boost_spouse_loyalty(character: Dictionary) -> Dictionary:
	"""通过礼物与关怀大幅提升妻子忠诚度。返回 {success, old_loyalty, new_loyalty, cost, message}"""
	var spouse = character.relationships.get("spouse", {})
	if spouse.is_empty():
		return {"success": false, "message": "你尚未娶妻。"}
	var cost = 15  # 花费15石
	if GameState.family_data.wealth < cost:
		return {"success": false, "message": "需至少%d石才能博妻子欢心。" % cost}
	# CHA掷骰决定效果
	var cha_bonus = DiceSystem.attr_to_bonus(character.attributes.get("cha", 10))
	var roll = DiceSystem.roll_dice("2d6", cha_bonus, 0)
	var tier = roll.get("tier", 2)
	var old_loyalty = spouse.get("loyalty", 80)
	var boost = 0
	var msg = ""
	match tier:
		0: boost = 30; msg = "妻子感动不已，忠诚+30！"
		1: boost = 20; msg = "妻子心花怒放，忠诚+20。"
		2: boost = 15; msg = "妻子颇为欢喜，忠诚+15。"
		3: boost = 8; msg = "妻子稍感欣慰，忠诚+8。"
	var new_loyalty = min(100, old_loyalty + boost)
	spouse["loyalty"] = new_loyalty
	CharacterManager.modify_wealth(-cost)
	return {"success": true, "old_loyalty": old_loyalty, "new_loyalty": new_loyalty,
		"cost": cost, "message": msg + " 花费%d石。" % cost}

func can_take_concubine(character: Dictionary) -> Dictionary:
	"""检查是否可以纳妾。返回 {can: bool, reason: str, max_count: int, cost: int}"""
	var limits = SPOUSE_LIMITS.get(character.social_level, {"wife": 0, "concubine": 0, "tongfang": 0})
	var max_count = limits.get("concubine", 0)
	if max_count <= 0:
		return {"can": false, "reason": "你当前的等级无权纳妾。", "max_count": 0, "cost": 0}
	if not is_married(character):
		return {"can": false, "reason": "需先有正妻，方可纳妾。", "max_count": 0, "cost": 0}
	var level = character.social_level
	var cost = 0
	match level:
		3: cost = 30
		4: cost = 50
		5: cost = 80
		6: cost = 100
	var current = GameState.family_data.get("concubines", []).size()
	if current >= max_count:
		return {"can": false, "reason": "妾室已满（最多%d人）。" % max_count, "max_count": max_count, "cost": cost}
	if GameState.family_data.wealth < cost:
		return {"can": false, "reason": "纳妾需 %d 石，钱财不足。" % cost, "max_count": max_count, "cost": cost}
	return {"can": true, "reason": "", "max_count": max_count, "cost": cost, "current": current}

func take_concubine(character: Dictionary, surname: String, clan: String, cost: int) -> Dictionary:
	"""纳妾——扣除花费，生成妾室"""
	if GameState.family_data.wealth < cost:
		return {"success": false, "message": "纳妾需 %d 石，钱财不足。" % cost}
	if surname == character.surname:
		return {"success": false, "message": "同姓不婚！%s姓与%s姓不可通婚。" % [surname, character.surname]}
	CharacterManager.modify_wealth(-cost)
	var concubine = generate_spouse(surname, clan, max(16, character.age - randi_range(-3, 8)))
	concubine["married_year"] = GameState.current_year
	concubine["is_pregnant"] = false
	concubine["pregnancy_remaining"] = 0
	if not GameState.family_data.has("concubines"):
		GameState.family_data["concubines"] = []
	GameState.family_data.concubines.append(concubine)
	return {"success": true, "concubine": concubine, "cost": cost,
		"message": "纳%s%s·%s氏为妾——花费 %d 石。" % [surname, concubine.name, concubine.clan, cost]}

func can_take_tongfang(character: Dictionary) -> Dictionary:
	"""检查是否可以收通房丫头。返回 {can: bool, reason: str, max_count: int, cost: int, current: int}"""
	var limits = SPOUSE_LIMITS.get(character.social_level, {"wife": 0, "concubine": 0, "tongfang": 0})
	var max_count = limits.get("tongfang", 0)
	if max_count <= 0:
		return {"can": false, "reason": "你当前的等级无权收通房丫头。", "max_count": 0, "cost": 0}
	var cost = TONGFANG_COST_BASE + character.social_level * 5
	var current = GameState.family_data.get("tongfangs", []).size()
	if current >= max_count:
		return {"can": false, "reason": "通房丫头已满（最多%d人）。" % max_count, "max_count": max_count, "cost": cost, "current": current}
	if GameState.family_data.wealth < cost:
		return {"can": false, "reason": "收通房需 %d 石，钱财不足。" % cost, "max_count": max_count, "cost": cost, "current": current}
	return {"can": true, "reason": "", "max_count": max_count, "cost": cost, "current": current}

func take_tongfang(character: Dictionary, surname: String, clan: String, cost: int) -> Dictionary:
	"""收通房丫头——花费较少，出身低微"""
	if GameState.family_data.wealth < cost:
		return {"success": false, "message": "收通房需 %d 石，钱财不足。" % cost}
	CharacterManager.modify_wealth(-cost)
	var tf = generate_spouse(surname, clan, max(14, character.age - randi_range(-2, 10)))
	tf["married_year"] = GameState.current_year
	tf["is_pregnant"] = false
	tf["pregnancy_remaining"] = 0
	tf["loyalty"] = 60 + randi_range(0, 20)
	tf["last_affair_year"] = -9999
	if not GameState.family_data.has("tongfangs"):
		GameState.family_data["tongfangs"] = []
	GameState.family_data.tongfangs.append(tf)
	return {"success": true, "tongfang": tf, "cost": cost,
		"message": "收%s%s·%s氏为通房丫头——花费 %d 石。" % [surname, tf.name, tf.clan, cost]}

func can_take_furen(character: Dictionary) -> Dictionary:
	"""天子专属——纳夫人。返回 {can, reason, max_count, cost, current}"""
	if character.social_level < 6:
		return {"can": false, "reason": "唯有天子方可册立夫人。", "max_count": 0, "cost": 0}
	var limits = SPOUSE_LIMITS.get(6, {})
	var max_count = limits.get("furen", 3)
	var current = GameState.family_data.get("furens", []).size()
	if current >= max_count:
		return {"can": false, "reason": "三夫人已满——天子后宫：后一人、夫人三人、嫔九人。", "max_count": max_count, "cost": 0}
	if not is_married(character):
		return {"can": false, "reason": "需先立后，方可纳夫人。", "max_count": max_count, "cost": 0}
	var cost = 200
	if GameState.family_data.wealth < cost:
		return {"can": false, "reason": "册立夫人需 %d 石聘礼，钱财不足。" % cost, "max_count": max_count, "cost": cost}
	return {"can": true, "reason": "", "max_count": max_count, "cost": cost, "current": current}

func take_furen(character: Dictionary, surname: String, clan: String, cost: int) -> Dictionary:
	"""天子纳夫人——仅次于王后的尊贵配偶"""
	if GameState.family_data.wealth < cost:
		return {"success": false, "message": "册立夫人需 %d 石。" % cost}
	if surname == character.surname:
		return {"success": false, "message": "同姓不婚！%s姓与%s姓不可通婚。" % [surname, character.surname]}
	CharacterManager.modify_wealth(-cost)
	var furen = generate_spouse(surname, clan, max(16, character.age - randi_range(-3, 5)))
	furen["married_year"] = GameState.current_year
	furen["is_pregnant"] = false
	furen["pregnancy_remaining"] = 0
	furen["loyalty"] = 75 + randi_range(0, 15)
	furen["last_affair_year"] = -9999
	if not GameState.family_data.has("furens"):
		GameState.family_data["furens"] = []
	GameState.family_data.furens.append(furen)
	return {"success": true, "furen": furen, "cost": cost,
		"message": "册立%s%s·%s氏为夫人——位次王后，尊贵无比。花费 %d 石。" % [surname, furen.name, furen.clan, cost]}

func is_incestuous(char: Dictionary, target: Dictionary) -> Dictionary:
	"""检测两个角色之间是否存在乱伦关系。返回 {is_incest: bool, relation: str, severity: int}"""
	# 1. 同姓检测
	if char.get("surname", "") == target.get("surname", ""):
		return {"is_incest": true, "relation": "同姓", "severity": 2}
	# 2. 近亲检测——检查target是否在直系亲属中
	var parents = GameState.family_data.get("parents", {})
	if not parents.is_empty():
		var father = parents.get("father", {})
		var mother = parents.get("mother", {})
		if father.get("name", "") == target.get("name", "") and father.get("surname", "") == target.get("surname", ""):
			return {"is_incest": true, "relation": "父亲", "severity": 3}
		if mother.get("name", "") == target.get("name", "") and mother.get("surname", "") == target.get("surname", ""):
			return {"is_incest": true, "relation": "母亲", "severity": 3}
	# 3. 兄弟姐妹检测
	var siblings = GameState.family_data.get("siblings", [])
	for sib in siblings:
		if sib.get("name", "") == target.get("name", "") and sib.get("surname", "") == target.get("surname", ""):
			return {"is_incest": true, "relation": "兄弟姐妹", "severity": 3}
	# 4. 子女检测
	var children = char.get("relationships", {}).get("children", [])
	for c in children:
		if c.get("name", "") == target.get("name", "") and c.get("surname", "") == target.get("surname", ""):
			return {"is_incest": true, "relation": "子女", "severity": 3}
	return {"is_incest": false, "relation": "", "severity": 0}

func check_spouse_fidelity(character: Dictionary) -> Array:
	"""每季检测配偶和妾室的忠诚度。返回出轨通知列表 [{person, type, name, discovered}]。
	BUGFIX: luck_mod 10→0, 概率大幅降低, tier阈值修正"""
	var notices: Array = []
	var int_bonus: int = DiceSystem.attr_to_bonus(character.attributes.get("int", 10))
	# 检测正妻
	if is_married(character):
		var spouse = character.relationships.get("spouse", {})
		if not spouse.is_empty() and spouse.get("is_alive", true):
			var base_chance: float = 0.8  # 0.8% (曾3%)
			var loyalty = spouse.get("loyalty", 80)
			if loyalty < 30: base_chance += 3.0
			elif loyalty < 50: base_chance += 1.5
			if character.attributes.get("cha", 10) < 10: base_chance += 2.0
			if randf() * 100.0 < base_chance:
				spouse["last_affair_year"] = GameState.current_year
				spouse["loyalty"] = max(0, loyalty - 20)  # -20 (曾-30)
				var roll = DiceSystem.roll_dice("2d6", int_bonus, 0)  # BUGFIX: luck_mod=0 (曾10)
				var discovered: bool = roll.tier <= 1  # tier 0-1 = 发现 (曾tier>=2)
				notices.append({"person": spouse, "type": "wife", "name": spouse.get("name", ""), "discovered": discovered})
	# 检测每位妾室
	var concubines = GameState.family_data.get("concubines", [])
	for cn in concubines:
		if cn.is_empty() or not cn.get("is_alive", true):
			continue
		var base_chance: float = 1.5  # 1.5% (曾15%)
		var loyalty = cn.get("loyalty", 60)
		if loyalty < 30: base_chance += 3.0
		elif loyalty < 50: base_chance += 1.5
		if character.attributes.get("cha", 10) < 10: base_chance += 2.0
		if randf() * 100.0 < base_chance:
			cn["last_affair_year"] = GameState.current_year
			cn["loyalty"] = max(0, loyalty - 20)
			var roll = DiceSystem.roll_dice("2d6", int_bonus, 0)
			var discovered: bool = roll.tier <= 1
			notices.append({"person": cn, "type": "concubine", "name": cn.get("name", ""), "discovered": discovered})
	# 检测每位通房丫头
	var tongfangs = GameState.family_data.get("tongfangs", [])
	for tf in tongfangs:
		if tf.is_empty() or not tf.get("is_alive", true):
			continue
		var base_chance: float = 2.0
		var loyalty = tf.get("loyalty", 50)
		if loyalty < 30: base_chance += 4.0
		elif loyalty < 50: base_chance += 2.0
		if character.attributes.get("cha", 10) < 10: base_chance += 2.5
		if randf() * 100.0 < base_chance:
			tf["last_affair_year"] = GameState.current_year
			tf["loyalty"] = max(0, loyalty - 15)
			var roll = DiceSystem.roll_dice("2d6", int_bonus, 0)
			var discovered: bool = roll.tier <= 1
			notices.append({"person": tf, "type": "tongfang", "name": tf.get("name", ""), "discovered": discovered})
	# 检测每位夫人（天子后宫）
	var furens = GameState.family_data.get("furens", [])
	for fr in furens:
		if fr.is_empty() or not fr.get("is_alive", true):
			continue
		var base_chance: float = 0.5  # 夫人地位高，出轨率低
		var loyalty = fr.get("loyalty", 85)
		if loyalty < 30: base_chance += 2.0
		elif loyalty < 50: base_chance += 1.0
		if character.attributes.get("cha", 10) < 10: base_chance += 1.5
		if randf() * 100.0 < base_chance:
			fr["last_affair_year"] = GameState.current_year
			fr["loyalty"] = max(0, loyalty - 15)
			var roll = DiceSystem.roll_dice("2d6", int_bonus, 0)
			var discovered: bool = roll.tier <= 1
			notices.append({"person": fr, "type": "furen", "name": fr.get("name", ""), "discovered": discovered})
	# 检测每位媵妾（诸侯侧室）
	var ying_qie = GameState.family_data.get("ying_qie", [])
	for yq in ying_qie:
		if yq.is_empty() or not yq.get("is_alive", true):
			continue
		var base_chance: float = 1.0
		var loyalty = yq.get("loyalty", 70)
		if loyalty < 30: base_chance += 2.5
		elif loyalty < 50: base_chance += 1.5
		if character.attributes.get("cha", 10) < 10: base_chance += 2.0
		if randf() * 100.0 < base_chance:
			yq["last_affair_year"] = GameState.current_year
			yq["loyalty"] = max(0, loyalty - 15)
			var roll = DiceSystem.roll_dice("2d6", int_bonus, 0)
			var discovered: bool = roll.tier <= 1
			notices.append({"person": yq, "type": "ying_qie", "name": yq.get("name", ""), "discovered": discovered})
	return notices

# ============================================================
# 家庭系统（和睦度、成员关系）
# ============================================================

func get_household_members(char: Dictionary) -> Array:
	"""获取家庭所有同居成员列表。返回 [{id, name, type, age, mood}]"""
	var members: Array = []
	var age = get_character_age(char)
	members.append({"id": "self", "name": char.get("name", ""), "type": "家主", "age": age, "mood": _get_member_mood(char, "self")})
	# 正妻
	if is_married(char):
		var sp = char.relationships.get("spouse", {})
		if not sp.is_empty():
			var sp_age = GameState.current_year - sp.get("birth_year", GameState.current_year)
			members.append({"id": "wife", "name": sp.get("name", ""), "surname": sp.get("surname", ""), "type": "正妻", "age": sp_age, "mood": _get_member_mood(sp, "wife"), "pregnant": sp.get("is_pregnant", false)})
	# 夫人
	var furens = GameState.family_data.get("furens", [])
	for i in range(furens.size()):
		var fr = furens[i]
		var fr_age = GameState.current_year - fr.get("birth_year", GameState.current_year)
		members.append({"id": "furen_%d" % i, "name": fr.get("name", ""), "surname": fr.get("surname", ""), "type": "夫人", "age": fr_age, "mood": _get_member_mood(fr, "furen"), "pregnant": fr.get("is_pregnant", false)})
	# 媵妾
	var ying_qie = GameState.family_data.get("ying_qie", [])
	for i in range(ying_qie.size()):
		var yq = ying_qie[i]
		var yq_age = GameState.current_year - yq.get("birth_year", GameState.current_year)
		members.append({"id": "ying_%d" % i, "name": yq.get("name", ""), "surname": yq.get("surname", ""), "type": "媵妾", "age": yq_age, "mood": _get_member_mood(yq, "ying_qie"), "pregnant": yq.get("is_pregnant", false)})
	# 妾室
	var concubines = GameState.family_data.get("concubines", [])
	for i in range(concubines.size()):
		var cn = concubines[i]
		var cn_age = GameState.current_year - cn.get("birth_year", GameState.current_year)
		members.append({"id": "concubine_%d" % i, "name": cn.get("name", ""), "surname": cn.get("surname", ""), "type": "妾室", "age": cn_age, "mood": _get_member_mood(cn, "concubine"), "pregnant": cn.get("is_pregnant", false)})
	# 通房
	var tongfangs = GameState.family_data.get("tongfangs", [])
	for i in range(tongfangs.size()):
		var tf = tongfangs[i]
		var tf_age = GameState.current_year - tf.get("birth_year", GameState.current_year)
		members.append({"id": "tongfang_%d" % i, "name": tf.get("name", ""), "surname": tf.get("surname", ""), "type": "通房", "age": tf_age, "mood": _get_member_mood(tf, "tongfang"), "pregnant": tf.get("is_pregnant", false)})
	# 子女
	var children = char.relationships.get("children", [])
	for i in range(children.size()):
		var ch = children[i]
		if ch.get("is_alive", true) and not ch.get("is_separated", false):
			var ch_age = GameState.current_year - ch.get("birth_year", GameState.current_year)
			var ch_type = "嫡子" if (ch.gender == "male" and ch.get("mother_type", "") == "wife") else ("嫡女" if ch.gender == "female" and ch.get("mother_type", "") == "wife" else ("庶子" if ch.gender == "male" else "庶女"))
			members.append({"id": "child_%d" % i, "name": ch.get("name", ""), "surname": ch.get("surname", ""), "type": ch_type, "age": ch_age, "mood": _get_member_mood(ch, "child"), "heir": ch.get("is_heir", false), "education": ch.get("education_focus", "")})
	# 父母
	var parents = GameState.family_data.get("parents", {})
	if not parents.is_empty():
		var father = parents.get("father", {})
		if not father.is_empty() and father.get("is_alive", true):
			var f_age = GameState.current_year - father.get("birth_year", GameState.current_year)
			members.append({"id": "father", "name": father.get("name", ""), "type": "父亲", "age": f_age, "mood": _get_member_mood(father, "parent")})
		var mother = parents.get("mother", {})
		if not mother.is_empty() and mother.get("is_alive", true):
			var m_age = GameState.current_year - mother.get("birth_year", GameState.current_year)
			members.append({"id": "mother", "name": mother.get("name", ""), "type": "母亲", "age": m_age, "mood": _get_member_mood(mother, "parent")})
	return members

func _get_member_mood(member: Dictionary, member_type: String) -> String:
	"""根据忠诚度/状态返回成员心情"""
	if member_type == "child":
		return "活泼" if randf() < 0.7 else "调皮"
	if member_type == "parent":
		return "安康" if randf() < 0.7 else "体弱"
	if member_type == "self":
		return "正常"
	var loyalty = member.get("loyalty", 70)
	var pregnant = member.get("is_pregnant", false)
	if pregnant: return "安胎中"
	if loyalty >= 80: return "愉悦"
	if loyalty >= 60: return "平和"
	if loyalty >= 40: return "不满"
	if loyalty >= 20: return "怨怼"
	return "离心"

func calculate_household_harmony(char: Dictionary) -> int:
	"""计算家庭和睦度（0-100），每季调用"""
	var harmony = GameState.household_data.get("harmony", 60)
	# 正妻影响
	if is_married(char):
		var sp = char.relationships.get("spouse", {})
		var sp_loyalty = sp.get("loyalty", 70)
		if sp_loyalty > 70: harmony += HARMONY_FACTORS.wife_loyal
		elif sp_loyalty < 40: harmony += HARMONY_FACTORS.wife_discontent
	# 妾室/夫人/媵妾/通房 低忠诚度扣分
	var all_consorts = []
	for arr in [GameState.family_data.get("concubines", []), GameState.family_data.get("furens", []), GameState.family_data.get("ying_qie", []), GameState.family_data.get("tongfangs", [])]:
		for cn in arr:
			if cn.get("loyalty", 60) < 40:
				harmony += HARMONY_FACTORS.concubine_discontent
	# 丑闻
	if GameState.family_data.get("scandal_level", 0) > 2:
		harmony += HARMONY_FACTORS.scandal_penalty
	# 受教育子女
	var children = char.relationships.get("children", [])
	for ch in children:
		if ch.get("is_alive", true) and ch.get("education_focus", "") != "":
			harmony += HARMONY_FACTORS.child_educated
	# 成年未分家
	for ch in children:
		if ch.get("is_alive", true) and not ch.get("is_separated", false):
			var ch_age = GameState.current_year - ch.get("birth_year", GameState.current_year)
			if ch_age >= 16:
				harmony += HARMONY_FACTORS.adult_child_crowded
	# 怀孕加分
	var preg_count = 0
	var spouse = char.relationships.get("spouse", {})
	if spouse.get("is_pregnant", false): preg_count += 1
	for arr2 in [GameState.family_data.get("concubines", []), GameState.family_data.get("furens", []), GameState.family_data.get("ying_qie", []), GameState.family_data.get("tongfangs", [])]:
		for cn in arr2:
			if cn.get("is_pregnant", false): preg_count += 1
	if preg_count > 0:
		harmony += HARMONY_FACTORS.pregnancy_bonus * preg_count
	# 家庭私财压力
	if GameState.household_data.get("wealth", 0) < 0:
		harmony += HARMONY_FACTORS.wealth_stress
	# 立嗣
	var heir = get_heir(char)
	if not heir.is_empty():
		harmony += HARMONY_FACTORS.heir_designated
	return clampi(harmony, 0, 100)

func add_household_event(event_type: String, description: String) -> void:
	"""记录家庭事件"""
	if not GameState.household_data.has("events"):
		GameState.household_data["events"] = []
	GameState.household_data.events.append({
		"year": GameState.current_year,
		"type": event_type,
		"description": description
	})
	if GameState.household_data.events.size() > 20:
		GameState.household_data.events.pop_front()

# ============================================================
# 姐妹事件系统
# ============================================================

func check_sister_events(character: Dictionary) -> Dictionary:
	"""每季检测姐妹事件触发条件。返回事件数据或空字典。"""
	var age = get_character_age(character)
	if age < 16:
		return {}
	var scandal = GameState.family_data.get("scandal_level", 0)
	if scandal >= 5:
		return {}
	var siblings = GameState.family_data.get("siblings", [])
	for i in range(siblings.size()):
		var sib = siblings[i]
		if not sib.get("is_alive", true):
			continue
		if sib.get("gender", "") != "female":
			continue
		var sib_age = GameState.current_year - sib.get("birth_year", GameState.current_year)
		if sib_age < 16:
			continue
		# 检测姐妹是否已婚
		if _sibling_is_married(sib):
			continue
		var aff = get_sibling_affection(i)
		if aff < 80:
			continue
		# 年龄相近检测（相差5岁以内）
		var age_diff = abs(age - sib_age)
		if age_diff > 5:
			continue
		# 概率判定
		var chance = 15.0
		var cha = character.attributes.get("cha", 10)
		if cha >= 15:
			chance += 5.0
		if aff >= 90:
			chance += 10.0
		if randf() * 100.0 < chance:
			# 加权随机选择事件类型
			var events = [
				{"type": "sister_talk", "weight": 20, "title": "深夜谈心", "desc": "姐妹深夜来访，与你倾诉心事……", "affection_change": 5, "scandal": 0},
				{"type": "sister_close", "weight": 15, "title": "共处密室", "desc": "二人独处一室，气氛逐渐暧昧……", "affection_change": 8, "scandal": 0},
				{"type": "sister_incest", "weight": 10, "title": "肌肤之亲", "desc": "情难自禁，逾越了手足之界……", "affection_change": 15, "scandal": 0},
				{"type": "sister_letter", "weight": 12, "title": "情书往来", "desc": "姐妹书信传情，却被旁人发现了端倪。", "affection_change": -10, "scandal": 1},
				{"type": "sister_oppose", "weight": 8, "title": "家族察觉", "desc": "父母族人察觉到了你们之间不寻常的亲近。", "affection_change": -20, "scandal": 2},
			]
			var total_weight = 0
			for evt in events:
				total_weight += evt.weight
			var roll = randi_range(1, total_weight)
			var cumulative = 0
			for evt in events:
				cumulative += evt.weight
				if roll <= cumulative:
					evt["sibling_index"] = i
					evt["sibling_name"] = sib.get("name", "")
					evt["sibling_surname"] = sib.get("surname", "")
					return evt
	return {}

func resolve_sister_event(character: Dictionary, event: Dictionary, choice: int) -> Dictionary:
	"""处理姐妹事件选择结果。返回结果字典。"""
	var i = event.get("sibling_index", -1)
	var result = {"message": "", "scandal_add": 0, "reputation_change": 0}
	var event_type = event.get("type", "")
	match event_type:
		"sister_talk":
			match choice:
				0:  # 倾听陪伴
					modify_sibling_affection(i, 5)
					result.message = "你静静聆听姐妹的心事，她心满意足地回房去了。你们的感情更深了。"
				1:  # 保持距离
					modify_sibling_affection(i, -3)
					result.message = "你以天色已晚为由，送她回房。她脸上掠过一丝失落。"
		"sister_close":
			match choice:
				0:  # 顺其自然
					modify_sibling_affection(i, 8)
					result.message = "烛影摇红，你们相谈甚欢，不觉已至深夜……"
					if randf() < 0.3:
						result.scandal_add = 1
						result.reputation_change = -3
						result.message += " 但似乎有下人在外窥见了什么……"
				1:  # 借故离开
					modify_sibling_affection(i, -5)
					result.message = "你察觉到气氛不对，借故离开。她独自留在房中，神色黯然。"
		"sister_incest":
			match choice:
				0:  # 纵情
					modify_sibling_affection(i, 15)
					result.scandal_add = 2
					result.reputation_change = -8
					# 记录乱伦日志
					if not GameState.family_data.has("incest_log"):
						GameState.family_data["incest_log"] = []
					GameState.family_data.incest_log.append({
						"year": GameState.current_year,
						"person": event.get("sibling_name", ""),
						"relation": "姐妹",
						"discovered": false,
					})
					modify_scandal_level(2)
					# 怀孕判定
					var preg_result = handle_incest_pregnancy(character, i)
					result.message = "那一夜，你们逾越了禁忌……" + preg_result.get("message", "")
					if preg_result.get("pregnant", false):
						result.message += " 更糟的是，" + preg_result.get("pregnancy_note", "")
				1:  # 克制
					modify_sibling_affection(i, -15)
					result.message = "你在最后一刻清醒过来，推开了她。她掩面哭泣而去，此后数日都躲着你。"
		"sister_letter":
			match choice:
				0:  # 销毁证据
					modify_sibling_affection(i, -5)
					result.scandal_add = 0
					result.reputation_change = -2
					result.message = "你匆忙将书信付之一炬，但流言已经开始在仆人间传播……"
				1:  # 顺其自然
					modify_sibling_affection(i, 5)
					result.scandal_add = 1
					result.reputation_change = -5
					result.message = "你没有否认那些书信，族人议论纷纷，但姐妹对你的情意更加坚定了。"
		"sister_oppose":
			match choice:
				0:  # 低头认错
					modify_sibling_affection(i, -20)
					result.scandal_add = 1
					result.reputation_change = -5
					result.message = "你在族人面前低头认错，承诺不再与姐妹私下往来。家族风波暂时平息。"
				1:  # 强辩到底
					modify_sibling_affection(i, -10)
					result.scandal_add = 2
					result.reputation_change = -10
					result.message = "你据理力争，但族人已被流言左右。最终你虽未被逐出家族，但声望大损。"
	if result.scandal_add > 0:
		modify_scandal_level(result.scandal_add)
	if result.reputation_change != 0:
		modify_reputation(character, result.reputation_change)
	add_household_event("sister_event", result.message.left(50) + "…" if result.message.length() > 50 else result.message)
	return result

func handle_incest_pregnancy(character: Dictionary, sister_index: int) -> Dictionary:
	"""处理乱伦怀孕判定。返回 {pregnant, message, pregnancy_note}"""
	var siblings = GameState.family_data.get("siblings", [])
	if sister_index < 0 or sister_index >= siblings.size():
		return {"pregnant": false, "message": ""}
	var sister = siblings[sister_index]
	var fertility = 8.0  # 基础受孕率8%
	var cha_bonus = DiceSystem.attr_to_bonus(character.attributes.get("cha", 10))
	fertility += cha_bonus * 1.0  # CHA加成每点+1%
	var sib_age = GameState.current_year - sister.get("birth_year", GameState.current_year)
	if sib_age > 30:
		fertility = max(2.0, fertility - (sib_age - 30) * 1.0)
	if randf() * 100.0 < fertility:
		# 怀孕
		sister["is_pregnant"] = true
		sister["pregnancy_remaining"] = 3
		sister["pregnancy_type"] = "incest"
		return {"pregnant": true, "message": "她怀上了你的骨肉。",
			"pregnancy_note": "姐妹已有身孕——此子若生，必为孽种。"}
	return {"pregnant": false, "message": ""}

# 玩家主动偷情（1 年间隔）
func player_affair(character: Dictionary, target_surname: String, _target_clan: String, target_name: String, target_married: bool) -> Dictionary:
	"""玩家主动偷情。BUGFIX: luck_mod 8→0, 修正反向tier映射, 降低惩罚。
	乱伦检测由UI层完成——此函数处理实际的私会掷骰。"""
	var cha_bonus: int = DiceSystem.attr_to_bonus(character.attributes.get("cha", 10))
	var roll = DiceSystem.roll_dice("2d6", cha_bonus, 0)  # BUGFIX: luck_mod=0 (曾8)
	match roll.tier:
		0:  # final >= 13 — 大成功
			CharacterManager.modify_ambition(character, 1)
			return {"success": true, "discovered": false, "message": "🌙 与%s%s春风一度——得意非凡，野心+1。" % [target_surname, target_name], "penalty": 0}
		1:  # final >= 9 — 成功
			CharacterManager.modify_ambition(character, 0)
			return {"success": true, "discovered": false, "message": "🌙 与%s%s暗通款曲——无人知晓。" % [target_surname, target_name], "penalty": 0}
		2:  # final >= 5 — 部分成功，妻子起疑
			if is_married(character):
				var spouse = character.relationships.get("spouse", {})
				spouse["loyalty"] = max(0, spouse.get("loyalty", 50) - 8)
			return {"success": true, "discovered": false, "message": "🌙 与%s%s私会——然家中似有察觉，妻子忠诚-8。" % [target_surname, target_name], "penalty": 0}
		_:  # final < 5 — 失败被发现
			var penalty_val: int = -8  # (曾-15/-20)
			CharacterManager.modify_reputation(character, penalty_val)
			modify_scandal_level(1)
			GameState.family_data.get("infidelity_log", []).append({
				"year": GameState.current_year, "person": "%s·%s" % [target_surname, target_name],
				"discovered": true, "penalty": penalty_val, "action": "私会败露"
			})
			if is_married(character):
				var spouse = character.relationships.get("spouse", {})
				spouse["loyalty"] = max(0, spouse.get("loyalty", 50) - 20)
			if target_married:
				CharacterManager.modify_reputation(character, -5)
				return {"success": false, "discovered": true, "message": "🌙 与%s%s私通败露！对方有夫之妇——丑闻更甚！" % [target_surname, target_name], "penalty": penalty_val}
			return {"success": false, "discovered": true, "message": "🌙 与%s%s私会被人撞见——声名受损！" % [target_surname, target_name], "penalty": penalty_val}

func modify_scandal_level(delta: int) -> void:
	"""修改丑闻等级 0-5"""
	var current = GameState.family_data.get("scandal_level", 0)
	GameState.family_data["scandal_level"] = clampi(current + delta, 0, 5)

func get_di_shu_children(character: Dictionary) -> Dictionary:
	"""按嫡庶分类子女。返回 {di: Array, shu: Array}"""
	var children = character.relationships.get("children", [])
	var di = []
	var shu = []
	for c in children:
		if not c.get("is_alive", true):
			continue
		if c.get("mother_type", "wife") == "wife":
			di.append(c)
		else:
			shu.append(c)
	return {"di": di, "shu": shu}

func get_inheritance_order(character: Dictionary) -> Array:
	"""返回完整继承顺位列表（仅16岁以上男性）"""
	var children = character.relationships.get("children", [])
	var order: Array = []
	# 嫡子按年龄排序
	var di = []
	var shu = []
	for c in children:
		if not c.get("is_alive", true) or c.get("gender", "male") != "male":
			continue
		var age = GameState.current_year - c.get("birth_year", GameState.current_year)
		if age < 16:
			continue
		var entry = c.duplicate()
		entry["current_age"] = age
		if c.get("mother_type", "wife") == "wife":
			di.append(entry)
		else:
			shu.append(entry)
	# 嫡子按出生年份排（年长者优先）
	di.sort_custom(func(a, b): return a.birth_year < b.birth_year)
	shu.sort_custom(func(a, b): return a.birth_year < b.birth_year)
	order.append_array(di)
	order.append_array(shu)
	return order

func separate_family(character: Dictionary, child: Dictionary) -> Dictionary:
	"""分家：成年庶子/嫡次子带走部分家产独立"""
	var is_di = child.get("mother_type", "wife") == "wife"
	var wealth_ratio = 0.20 if is_di else 0.10
	var taken = int(GameState.family_data.wealth * wealth_ratio)
	CharacterManager.modify_wealth(-taken)
	child["is_separated"] = true
	# 记录支系
	var branch = {"founder_name": child.get("name", ""), "founder_surname": child.get("surname", ""),
		"wealth_taken": taken, "year": GameState.current_year, "is_di": is_di}
	GameState.family_data.branch_families.append(branch)
	return {"success": true, "wealth_taken": taken, "branch": branch,
		"message": "%s%s%s分家独立——带走 %d 石。" % [child.surname, child.name, "（嫡次子）" if is_di else "（庶子）", taken]}

# ============================================================
# 子女婚嫁系统
# ============================================================
func marry_out_daughter(character: Dictionary, daughter: Dictionary) -> Dictionary:
	"""嫁女：女儿出嫁，获得聘礼，女子离开本家"""
	var da: int = GameState.current_year - daughter.get("birth_year", GameState.current_year)
	if da < 16:
		return {"success": false, "message": "女儿尚未成年，不可出嫁。"}
	if not daughter.get("is_alive", true):
		return {"success": false, "message": "此人已不在人世……"}
	if daughter.get("is_married_out", false):
		return {"success": false, "message": "此女已经出嫁。"}
	# 聘礼：根据父亲声望浮动
	var rep = character.derived.get("reputation", 0)
	var bride_price := 15 + randi_range(0, 15) + int(rep / 10)
	CharacterManager.modify_wealth(bride_price)
	# 声望增加
	var rep_gain := 3 + randi_range(0, 5)
	CharacterManager.modify_reputation(character, rep_gain)
	# 为女儿生成配偶（异姓）
	var spouse_surname = ""
	for s in EIGHT_SURNAMES:
		if s != character.surname:
			spouse_surname = s
			break
	var spouse_age = da + randi_range(-2, 8)
	var son_in_law = generate_spouse(spouse_surname, "", spouse_age)
	daughter["is_married_out"] = true
	daughter["spouse"] = son_in_law
	daughter["married_year"] = GameState.current_year
	daughter["bride_price"] = bride_price
	# 记录支系
	var branch = {"founder_name": daughter.get("name", ""), "founder_surname": daughter.get("surname", ""),
		"type": "married_out", "bride_price": bride_price, "year": GameState.current_year}
	if not GameState.family_data.has("branch_families"):
		GameState.family_data["branch_families"] = []
	GameState.family_data.branch_families.append(branch)
	return {"success": true, "bride_price": bride_price, "rep_gain": rep_gain,
		"message": "🏮 %s%s出嫁%s·%s氏——聘礼 %d 石，声望+%d。" % [
			daughter.surname, daughter.name, son_in_law.surname, son_in_law.clan, bride_price, rep_gain]}

func marry_in_son(character: Dictionary, son: Dictionary) -> Dictionary:
	"""为子娶妻：支付聘礼，为儿子迎娶妻子"""
	var sa: int = GameState.current_year - son.get("birth_year", GameState.current_year)
	if sa < 16:
		return {"success": false, "message": "儿子尚未成年，不可娶妻。"}
	if not son.get("is_alive", true):
		return {"success": false, "message": "此人已不在人世……"}
	if son.has("spouse") and not son.spouse.is_empty():
		return {"success": false, "message": "此子已有妻室。"}
	# 聘礼花费
	var cost := 15 + randi_range(0, 20)
	if GameState.family_data.wealth < cost:
		return {"success": false, "message": "聘礼不足！需要 %d 石，你只有 %d 石。" % [cost, GameState.family_data.wealth]}
	CharacterManager.modify_wealth(-cost)
	# 声望增加
	var rep_gain := 2 + randi_range(0, 3)
	CharacterManager.modify_reputation(character, rep_gain)
	# 为儿子生成儿媳（异姓）
	var spouse_surname = ""
	for s in EIGHT_SURNAMES:
		if s != son.get("surname", character.surname):
			spouse_surname = s
			break
	var spouse_age = sa + randi_range(-3, 3)
	var daughter_in_law = generate_spouse(spouse_surname, "", spouse_age)
	daughter_in_law["gender"] = "female"
	son["spouse"] = daughter_in_law
	son["married_year"] = GameState.current_year
	return {"success": true, "cost": cost, "rep_gain": rep_gain, "spouse": daughter_in_law,
		"message": "💒 为%s%s娶妻%s%s·%s氏——聘礼 %d 石，声望+%d。" % [
			son.surname, son.name, spouse_surname, daughter_in_law.name, daughter_in_law.clan, cost, rep_gain]}

func get_heir(character: Dictionary) -> Dictionary:
	"""获取继承人——嫡长子优先，嫡次子次之，庶子再次。若无直系成年男性，尝试旁系。
	返回 Dictionary（含current_age），若无继承人返回空{}。"""
	# 1. 优先：嫡庶顺位中的直系继承人
	var order = get_inheritance_order(character)
	if not order.is_empty():
		return order[0]
	# 2. 次选：未成年嫡长子（待其成年）
	var children = character.relationships.get("children", [])
	var best_underage = {}
	for child in children:
		if not child.get("is_alive", true) or child.get("gender", "male") != "male":
			continue
		if child.get("mother_type", "wife") != "wife":
			continue
		var age = GameState.current_year - child.get("birth_year", GameState.current_year)
		if best_underage.is_empty() or child.birth_year < best_underage.birth_year:
			best_underage = child.duplicate()
			best_underage["current_age"] = age
	if not best_underage.is_empty():
		return best_underage
	# 3. 旁系：兄弟及其子孙
	return get_collateral_heir(character)

func get_collateral_heir(character: Dictionary) -> Dictionary:
	"""旁系继承：从兄弟中寻找成年男性继承人。若无返回空{}。"""
	var siblings = GameState.family_data.get("siblings", [])
	var best = {}
	for sib in siblings:
		if not sib.get("is_alive", true) or sib.get("gender", "male") != "male":
			continue
		var age = GameState.current_year - sib.get("birth_year", GameState.current_year)
		if age >= 16:
			if best.is_empty() or sib.birth_year < best.birth_year:
				best = sib.duplicate()
				best["current_age"] = age
				best["relation"] = "旁系（兄弟）"
	return best

func create_heir_character(character: Dictionary, heir: Dictionary) -> Dictionary:
	var age = GameState.current_year - heir.birth_year
	var new_char = {
		"id": "char_%d" % Time.get_unix_time_from_system(),
		"name": heir.get("name", ""), "surname": heir.surname,
		"clan": character.clan, "ethnicity": character.ethnicity,
		"gender": heir.get("gender", "male"),
		"birth_year": heir.birth_year, "age": age, "is_alive": true,
		"social_class": character.social_class, "social_level": character.social_level,
		"profession": character.profession,
		"attributes": heir.attributes, "derived": {},
		"skills": ["礼法:1", "书数:1"],
		"inventory": [], "reputation": int(character.reputation / 3),
		"wealth": 0, "ambition": 15, "legitimacy": 0,
		"relationships": {"spouse": null, "children": [], "rivals": [], "allies": []},
		"status_flags": []
	}
	new_char.derived = _calculate_derived(new_char)
	return new_char

# ============================================================
# ============================================================
# 兄弟事件系统
# ============================================================

func check_brother_events(character: Dictionary) -> Dictionary:
	"""每季检测兄弟事件触发条件。返回事件数据或空字典。"""
	var age = get_character_age(character)
	if age < 16:
		return {}
	var siblings = GameState.family_data.get("siblings", [])
	for i in range(siblings.size()):
		var sib = siblings[i]
		if not sib.get("is_alive", true):
			continue
		if sib.get("gender", "") != "male":
			continue
		if sib.get("is_separated", false):
			continue
		var sib_age = GameState.current_year - sib.get("birth_year", GameState.current_year)
		if sib_age < 16:
			continue
		var aff = get_sibling_affection(i)
		if aff < 70:
			continue
		var chance = 12.0
		if randf() * 100.0 < chance:
			# 正面事件为主（权重70%），高好感时有负面可能
			var pos_weight = 70 if aff < 85 else 55
			var neg_weight = 30 if aff < 85 else 45
			if randf() * 100.0 < pos_weight:
				var positive_events = [
					{"type": "bro_cover", "weight": 15, "title": "代为受过", "desc": "兄弟主动替你承担了一次过失。", "affection_change": 10, "reputation": 0, "wealth": 0},
					{"type": "bro_conspire", "weight": 12, "title": "共谋大计", "desc": "兄弟与你商议大事，愿助你一臂之力。", "affection_change": 8, "reputation": 0, "wealth": 0},
					{"type": "bro_gift", "weight": 10, "title": "财产相赠", "desc": "兄弟将私财赠你，以表手足之情。", "affection_change": 5, "reputation": 0, "wealth": 5 + randi_range(0, 10)},
					{"type": "bro_save_life", "weight": 8, "title": "战场救命", "desc": "危难时刻，兄弟挺身而出，救你于险境。", "affection_change": 20, "reputation": 0, "wealth": 0},
					{"type": "bro_yield_heir", "weight": 5, "title": "让嗣", "desc": "兄弟主动表示愿意让出继承权。", "affection_change": 15, "reputation": 3, "wealth": 0},
				]
				var total = 0
				for evt in positive_events: total += evt.weight
				var roll = randi_range(1, total)
				var cum = 0
				for evt in positive_events:
					cum += evt.weight
					if roll <= cum:
						evt["sibling_index"] = i
						evt["sibling_name"] = sib.get("name", "")
						evt["sibling_surname"] = sib.get("surname", "")
						evt["is_negative"] = false
						return evt
			else:
				var negative_events = [
					{"type": "bro_heir_fight", "weight": 10, "title": "争嗣冲突", "desc": "谁是嫡长？兄弟为此争执不休。", "affection_change": -25, "reputation": -10, "wealth": 0},
					{"type": "bro_drunk", "weight": 8, "title": "酒后失言", "desc": "兄弟酒醉后透露了你的秘密。", "affection_change": -15, "reputation": -5, "wealth": 0},
					{"type": "bro_death", "weight": 5, "title": "意外身亡", "desc": "兄弟在外打猎时遭遇意外，不幸身亡。", "affection_change": 0, "reputation": 0, "wealth": 0},
					{"type": "bro_jealous", "weight": 7, "title": "嫉妒生隙", "desc": "兄弟嫉妒你的成就，心生不满。", "affection_change": -20, "reputation": 0, "wealth": 0},
					{"type": "bro_split_wealth", "weight": 6, "title": "分家纠纷", "desc": "分家之时，兄弟要求多分财产。", "affection_change": -10, "reputation": 0, "wealth": -(10 + randi_range(0, 20))},
				]
				var total2 = 0
				for evt in negative_events: total2 += evt.weight
				var roll2 = randi_range(1, total2)
				var cum2 = 0
				for evt in negative_events:
					cum2 += evt.weight
					if roll2 <= cum2:
						evt["sibling_index"] = i
						evt["sibling_name"] = sib.get("name", "")
						evt["sibling_surname"] = sib.get("surname", "")
						evt["is_negative"] = true
						return evt
	return {}

func resolve_brother_event(character: Dictionary, event: Dictionary, choice: int) -> Dictionary:
	"""处理兄弟事件选择结果。返回结果字典。"""
	var i = event.get("sibling_index", -1)
	var result = {"message": "", "reputation_change": 0, "wealth_change": 0, "sibling_died": false}
	var event_type = event.get("type", "")
	match event_type:
		"bro_cover":
			modify_sibling_affection(i, 10)
			result.message = "兄弟「%s」替你承担了过失，外人无从知晓你的过错。兄弟情深，莫过于此。" % event.get("sibling_name", "")
		"bro_conspire":
			modify_sibling_affection(i, 8)
			result.message = "你与兄弟密谈至深夜，共商大计。有了这份助力，未来若有举事，胜算大增。"
		"bro_gift":
			modify_sibling_affection(i, 5)
			var amount = event.get("wealth", 5 + randi_range(0, 10))
			result.wealth_change = amount
			modify_wealth(amount)
			result.message = "兄弟「%s」赠你%d石，助你渡过难关。" % [event.get("sibling_name", ""), amount]
		"bro_save_life":
			modify_sibling_affection(i, 20)
			result.message = "危急关头，兄弟「%s」舍命相护！你安然无恙，但这份恩情永世难忘。" % event.get("sibling_name", "")
		"bro_yield_heir":
			modify_sibling_affection(i, 15)
			result.reputation_change = 3
			result.message = "兄弟「%s」主动让嗣，在族人面前明确表示愿辅佐你的子嗣继承家业。此举令族人敬服。" % event.get("sibling_name", "")
		"bro_heir_fight":
			match choice:
				0:  # 据理力争
					modify_sibling_affection(i, -25)
					result.reputation_change = -10
					result.message = "你与兄弟在族人面前争执不下，家族因此分裂。声望大损。"
				1:  # 退让妥协
					modify_sibling_affection(i, -10)
					result.reputation_change = -3
					result.message = "你选择退让一步，避免了正面冲突。兄弟暂时偃旗息鼓，但裂痕已生。"
		"bro_drunk":
			modify_sibling_affection(i, -15)
			result.reputation_change = -5
			modify_scandal_level(1)
			result.message = "兄弟在酒宴上失言，透露了你的隐秘。众目睽睽之下，你颜面尽失。"
		"bro_death":
			var siblings = GameState.family_data.get("siblings", [])
			if i >= 0 and i < siblings.size():
				siblings[i]["is_alive"] = false
			result.sibling_died = true
			result.message = "天有不测风云——兄弟「%s」在外遭遇不测，不幸身亡。族中哀恸。" % event.get("sibling_name", "")
			add_household_event("brother_death", "兄弟" + event.get("sibling_name", "") + "意外身亡")
		"bro_jealous":
			modify_sibling_affection(i, -20)
			result.message = "你的成功让兄弟「%s」心生妒忌。自此他渐行渐远，不复往日亲密。" % event.get("sibling_name", "")
		"bro_split_wealth":
			modify_sibling_affection(i, -10)
			var loss = abs(event.get("wealth", -15))
			result.wealth_change = -loss
			modify_wealth(-loss)
			result.message = "分家纠纷中，兄弟「%s」多分了%d石财产。你心中不忿，却也无可奈何。" % [event.get("sibling_name", ""), loss]
	if result.reputation_change != 0:
		modify_reputation(character, result.reputation_change)
	add_household_event("brother_event", event.get("title", "兄弟事件") + "——" + result.message)
	return result

# 子女教育系统
# ============================================================
const EDUCATION_DIRECTIONS = {
	"文武": {"attrs": ["str", "int"], "skills": ["射御", "兵法"], "icon": "⚔", "desc": "习武修文，为将帅之才"},
	"礼乐": {"attrs": ["vir", "cha"], "skills": ["礼法", "乐"], "icon": "🎺", "desc": "通礼习乐，为庙堂之士"},
	"书数": {"attrs": ["int"], "skills": ["书数", "兵法"], "icon": "📐", "desc": "研习书数，为吏治之才"},
	"游说": {"attrs": ["cha"], "skills": ["游说", "礼法"], "icon": "📣", "desc": "辩才无碍，为外交之臣"},
}

func set_child_education_direction(child: Dictionary, direction: String) -> Dictionary:
	"""为子女设置教育方向。6岁以下只能'启蒙'。"""
	if not child.get("is_alive", true):
		return {"success": false, "message": "该子女已不在人世。"}
	var age = GameState.current_year - child.get("birth_year", GameState.current_year)
	if age < 1:
		return {"success": false, "message": "孩子尚在襁褓，无法教育。"}
	if age < 6 and direction != "":
		return {"success": false, "message": "未满6岁，只能进行启蒙教育。待其6岁后方可指定方向。"}
	if direction != "" and not EDUCATION_DIRECTIONS.has(direction):
		return {"success": false, "message": "无效的教育方向：%s" % direction}
	child["education_focus"] = direction
	if direction == "":
		return {"success": true, "message": "%s%s的启蒙教育已取消。" % [child.surname, child.name]}
	return {"success": true, "message": "%s%s的教育方向定为「%s」——%s" % [child.surname, child.name, direction, EDUCATION_DIRECTIONS[direction].desc]}

func process_child_education(character: Dictionary) -> Array:
	"""每季推进子女教育进度。返回通知列表。"""
	var notices: Array = []
	var children = character.relationships.get("children", [])
	for child in children:
		if not child.get("is_alive", true):
			continue
		var age = GameState.current_year - child.get("birth_year", GameState.current_year)
		var focus = child.get("education_focus", "")
		if focus == "":
			continue
		var prog = child.get("education_progress", 0)
		# 基础进度 8-15，受父母INT加成
		var parent_int = character.attributes.get("int", 10)
		var gain = 8 + randi_range(0, 7) + DiceSystem.attr_to_bonus(parent_int)
		prog += gain
		child["education_progress"] = prog
		if prog >= 100:
			prog -= 100
			child["education_progress"] = prog
			# 完成一个教育周期——属性/技能加成
			var dir_info = EDUCATION_DIRECTIONS.get(focus, {})
			var attrs = dir_info.get("attrs", [])
			var skills = dir_info.get("skills", [])
			for attr in attrs:
				if child.has("attributes") and child.attributes.has(attr):
					child.attributes[attr] = mini(child.attributes[attr] + 1, 20)
			for sk in skills:
				add_child_skill(child, sk, 1)
			var age_str = ""
			if age >= 16:
				# 成年结算
				child["education_bonus"] = child.get("education_bonus", 0) + 2
				age_str = "——已成年，学有所成！"
			notices.append("🎓 %s%s「%s」教育圆满%s %s+1。" % [child.surname, child.name, focus, age_str, "+".join(attrs + skills)])
	return notices

func finalize_child_adulthood(character: Dictionary) -> Array:
	"""子女16岁成年结算：根据教育方向分配初始职业与技能。"""
	var notices: Array = []
	var children = character.relationships.get("children", [])
	var dir_to_professions = {
		"文武": ["武士", "邑宰"],
		"礼乐": ["巫祝", "教师"],
		"书数": ["小吏", "教师"],
		"游说": ["门客", "游士"],
	}
	for child in children:
		if not child.get("is_alive", true):
			continue
		var age = GameState.current_year - child.get("birth_year", GameState.current_year)
		if age != 16:
			continue
		if child.get("_adulthood_finalized", false):
			continue
		child["_adulthood_finalized"] = true
		var focus = child.get("education_focus", "")
		# 成年属性微调
		if child.has("attributes"):
			child.attributes.str = mini(child.attributes.str + randi_range(0, 2), 20)
			child.attributes.con = mini(child.attributes.con + randi_range(0, 2), 20)
		# 分配初始职业
		var profs = dir_to_professions.get(focus, ["小吏"])
		child["profession"] = profs[randi_range(0, profs.size() - 1)]
		# 至少保证基础技能
		if not child.has("skills") or child.skills.is_empty():
			child["skills"] = ["礼法:1", "书数:1"]
		var is_heir = child.get("is_heir", false)
		var heir_tag = "（继承人）" if is_heir else ""
		notices.append("🎓 %s%s年满16岁，正式成年！教育方向「%s」，初始职业：%s。%s" % [child.surname, child.name, focus, child.get("profession", "无"), heir_tag])
	return notices

func check_child_milestones(character: Dictionary) -> Array:
	# 检查每个子女是否达到年龄里程碑，自动获得技能
	var milestones = []
	var children = character.relationships.get("children", [])
	for child in children:
		if not child.get("is_alive", true):
			continue
		var age = GameState.current_year - child.birth_year
		if not child.has("milestones_reached"):
			child["milestones_reached"] = []
		if not child.has("skills"):
			child["skills"] = []
		if not child.has("education_bonus"):
			child["education_bonus"] = 0
		var bonus = child.get("education_bonus", 0)

		# 6岁开蒙
		if age >= 6 and not child.milestones_reached.has(6):
			child.milestones_reached.append(6)
			add_child_skill(child, "书数", 1 + mini(bonus, 2))
			milestones.append("%s%s年满6岁，开蒙学习书数。" % [child.surname, child.name])
		# 12岁学礼
		if age >= 12 and not child.milestones_reached.has(12):
			child.milestones_reached.append(12)
			add_child_skill(child, "礼法", 1 + mini(bonus, 2))
			milestones.append("%s%s年满12岁，开始学习礼法。" % [child.surname, child.name])
		# 16岁成人
		if age >= 16 and not child.milestones_reached.has(16):
			child.milestones_reached.append(16)
			add_child_skill(child, "射御", 1 + mini(bonus, 2))
			milestones.append("%s%s年满16岁，成年习射御。" % [child.surname, child.name])
			# 成年结算
			var adult_notices = finalize_child_adulthood(character)
			milestones.append_array(adult_notices)
	return milestones

func add_child_skill(child: Dictionary, skill_name: String, level: int) -> void:
	if not child.has("skills"):
		child["skills"] = []
	for i in range(child.skills.size()):
		if child.skills[i].begins_with(skill_name + ":"):
			var cur = int(child.skills[i].split(":")[1])
			child.skills[i] = skill_name + ":" + str(mini(cur + level, 5))
			return
	child.skills.append(skill_name + ":" + str(level))

func educate_child(character: Dictionary, child_index: int, subject: String) -> Dictionary:
	var children = character.relationships.get("children", [])
	if child_index < 0 or child_index >= children.size():
		return {"success": false, "message": "无效的子女索引。"}
	var child = children[child_index]
	if not child.get("is_alive", true):
		return {"success": false, "message": "该子女已不在人世。"}
	var age = GameState.current_year - child.birth_year
	if age < 1:
		return {"success": false, "message": "孩子太小，还不能接受教育。"}
	if not child.has("skills"):
		child["skills"] = []
	if not child.has("education_bonus"):
		child["education_bonus"] = 0

	# 教育效果：INT掷骰决定教学质量
	var parent_int = character.attributes.get("int", 10)
	var intensity = 0
	var roll = randi_range(1, 6) + randi_range(1, 6) + DiceSystem.attr_to_bonus(parent_int)
	if roll >= 13:
		intensity = 2
	elif roll >= 9:
		intensity = 1

	if intensity > 0:
		add_child_skill(child, subject, intensity)
		child.education_bonus += 1
		return {"success": true, "intensity": intensity, "subject": subject,
			"message": "%s%s学习%s——%s（+%d级）" % [
				child.surname, child.name, subject,
				"大有所成！" if intensity >= 2 else "有所进步。", intensity
			]}
	else:
		return {"success": false, "intensity": 0, "message": "%s%s学习%s——效果不佳，未能提升。" % [child.surname, child.name, subject]}

# ============================================================
# 父母系统（0岁开局）
# ============================================================
func generate_parents(child_surname: String) -> Dictionary:
	var father_names = ["伯阳", "仲尼", "叔梁", "季孙", "子车", "公孙", "梁丘", "华元"]
	var mother_names = ["仲姜", "孟任", "叔姬", "季嬴", "伯芈", "少姚", "淑姜", "惠姬"]
	var father_age := 20 + randi_range(0, 15)
	var father = {
		"name": father_names[randi_range(0, father_names.size() - 1)],
		"surname": child_surname,
		"clan": "",
		"age": father_age,
		"birth_year": GameState.current_year - father_age,
		"is_alive": true,
		"profession": SHI_PROFESSIONS[randi_range(0, SHI_PROFESSIONS.size() - 1)].id,
	}
	# 母亲必须异姓（同姓不婚）
	var mother_surnames = []
	for s in EIGHT_SURNAMES:
		if s != child_surname:
			mother_surnames.append(s)
	var mother_surname = mother_surnames[randi_range(0, mother_surnames.size() - 1)]
	var mother_age := 18 + randi_range(0, 12)
	var mother = {
		"name": mother_names[randi_range(0, mother_names.size() - 1)],
		"surname": mother_surname,
		"clan": "",
		"age": mother_age,
		"birth_year": GameState.current_year - mother_age,
		"is_alive": true,
	}
	return {"father": father, "mother": mother, "family_wealth": 40 + randi_range(0, 80)}

func ask_parents_for_money(character: Dictionary, amount: int) -> Dictionary:
	if not GameState.family_data.has("parents"):
		return {"success": false, "message": "你没有父母可以求助。"}
	var parents = GameState.family_data.parents
	var father_alive = parents.father.get("is_alive", false)
	var mother_alive = parents.mother.get("is_alive", false)
	if not father_alive and not mother_alive:
		return {"success": false, "message": "父母已不在人世……"}
	var family_pool = parents.get("family_wealth", 0)
	if family_pool <= 0:
		return {"success": false, "message": "家族已经一贫如洗，拿不出钱了。"}
	var given = mini(amount, family_pool)
	parents.family_wealth -= given
	CharacterManager.modify_wealth(given)
	var giver = ""
	if father_alive:
		giver = "父亲%s%s" % [parents.father.surname, parents.father.name]
	elif mother_alive:
		giver = "母亲%s%s" % [parents.mother.surname, parents.mother.name]
	return {"success": true, "amount": given, "message": "%s给了你 %d 石。" % [giver, given]}


# ============================================================
# 兄弟姐妹系统
# ============================================================
func generate_siblings(child_surname: String, father_age: int, mother_age: int) -> Array:
	"""为玩家角色生成兄弟姐妹（年长的哥哥姐姐）。返回 Array[Dictionary]"""
	var siblings: Array = []
	var count: int = randi_range(0, 3)  # 0-3个兄弟姐妹
	if count == 0:
		return siblings

	var male_names := ["伯禽", "仲山", "叔向", "季札", "子产", "子思", "无忌", "去疾"]
	var female_names := ["仲姜", "季嬴", "孟任", "叔姬", "伯芈", "少姚", "淑姬"]

	# 母亲异姓（同姓不婚），姐妹随母姓
	var mother_surname := ""
	var mother_surnames: Array = []
	for s in EIGHT_SURNAMES:
		if s != child_surname:
			mother_surnames.append(s)
	if not mother_surnames.is_empty():
		mother_surname = mother_surnames[randi_range(0, mother_surnames.size() - 1)]

	for i in range(count):
		var gender: String = "male" if randf() < 0.5 else "female"
		var pool: Array = male_names if gender == "male" else female_names
		# 兄弟姐妹比玩家年长 1-10 岁
		var age_val: int = 1 + randi_range(0, 9)
		var sib_surname: String = child_surname if gender == "male" else mother_surname

		var sibling: Dictionary = {
			"name": pool[randi_range(0, pool.size() - 1)],
			"surname": sib_surname,
			"gender": gender,
			"age": age_val,
			"birth_year": GameState.current_year - age_val,
			"is_alive": randf() > 0.05,  # 5% 夭折率
			"relation": "兄" if gender == "male" else "姐"
		}
		siblings.append(sibling)

	return siblings


func _compute_age(member: Dictionary) -> int:
	"""统一年龄计算：优先 birth_year，旧档降级使用 age 字段"""
	if member.has("birth_year") and typeof(member.birth_year) == TYPE_INT:
		return GameState.current_year - member.birth_year
	return member.get("age", 0)

func get_sibling_kinship(sibling: Dictionary, player_age: int) -> String:
	"""返回正确的兄弟姐妹称谓"""
	var sib_age: int = _compute_age(sibling)
	if sibling.gender == "male":
		return "兄" if sib_age > player_age else "弟"
	else:
		return "姐" if sib_age > player_age else "妹"

# ============================================================
# 好感度系统
# ============================================================

func get_sibling_affection(sibling_index: int) -> int:
	"""获取指定兄弟姐妹对玩家的好感度"""
	var key = "sibling_%d" % sibling_index
	var relations = GameState.household_data.get("member_relations", {})
	if not relations.has(key):
		return 0
	return relations[key].get("self", 0)

func modify_sibling_affection(sibling_index: int, delta: int) -> void:
	"""修改好感度，钳制在 -100~100"""
	var key = "sibling_%d" % sibling_index
	var relations = GameState.household_data.get("member_relations", {})
	if not relations.has(key):
		relations[key] = {"self": 0}
	var current = relations[key].get("self", 0)
	relations[key]["self"] = clampi(current + delta, -100, 100)
	GameState.household_data["member_relations"] = relations

func set_sibling_affection(sibling_index: int, value: int) -> void:
	"""直接设置好感度"""
	var key = "sibling_%d" % sibling_index
	var relations = GameState.household_data.get("member_relations", {})
	relations[key] = {"self": clampi(value, -100, 100)}
	GameState.household_data["member_relations"] = relations

func get_affection_label(value: int) -> String:
	"""根据好感度数值返回中文标签"""
	var thresholds = AFFECTION_LABELS.keys()
	thresholds.sort()
	var label = "反目成仇"
	for threshold in thresholds:
		if value >= threshold:
			label = AFFECTION_LABELS[threshold]
	return label

func init_sibling_affection(sibling_index: int) -> void:
	"""为新兄弟姐妹初始化好感度（40-60）"""
	var key = "sibling_%d" % sibling_index
	var relations = GameState.household_data.get("member_relations", {})
	if not relations.has(key):
		relations[key] = {"self": 40 + randi_range(0, 20)}
		GameState.household_data["member_relations"] = relations

func _sibling_is_married(sibling: Dictionary) -> bool:
	"""判断姐妹是否已婚（简易检测——检查是否有配偶相关字段）"""
	return sibling.get("is_married", false) or sibling.get("spouse", {}) != {}



func update_parents_aging() -> Dictionary:
	"""随时间推进更新父母和兄弟姐妹的年龄与存活状态。返回死亡通知和待处理丧事。"""
	var notices: Array = []
	var pending_funeral: Array = []
	if GameState.family_data.has("parents"):
		var parents = GameState.family_data.parents
		if parents.father.get("is_alive", false):
			parents.father.age = _compute_age(parents.father)
			if parents.father.age > 55 and randf() < 0.08:
				parents.father.is_alive = false
				pending_funeral.append({"relation": "father", "name": parents.father.get("name", ""), "age": parents.father.age})
		if parents.mother.get("is_alive", false):
			parents.mother.age = _compute_age(parents.mother)
			if parents.mother.age > 55 and randf() < 0.08:
				parents.mother.is_alive = false
				pending_funeral.append({"relation": "mother", "name": parents.mother.get("name", ""), "age": parents.mother.age})
		for sibling in GameState.family_data.get("siblings", []):
			if sibling.get("is_alive", false):
				sibling.age = _compute_age(sibling)
				if sibling.age > 55 and randf() < 0.06:
					sibling.is_alive = false
					notices.append("☠ 手足%s%s去世，享年%d岁。" % [sibling.get("surname", ""), sibling.get("name", ""), sibling.age])
	# 配偶老化
	var char = GameState.current_character
	if not char.is_empty() and CharacterManager.is_married(char):
		var spouse = char.relationships.spouse
		spouse["age"] = _compute_age(spouse)
		if spouse.age > 55 and randf() < 0.06:
			notices.append("☠ 配偶%s%s·%s氏去世，享年%d岁。" % [spouse.get("surname", ""), spouse.get("name", ""), spouse.get("clan", ""), spouse.age])
	# 子女老化
	var children = CharacterManager.get_character_children(char)
	for child in children:
		if child.get("is_alive", true):
			var child_age = _compute_age(child)
			if child_age > 50 and randf() < 0.04:
				child["is_alive"] = false
				notices.append("☠ 子女%s%s去世，享年%d岁。" % [child.get("surname", ""), child.get("name", ""), child_age])
	return {"notices": notices, "pending_funeral": pending_funeral}
