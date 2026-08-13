# CharacterCreateUI.gd — 角色创建界面
extends Control

@onready var dynasty_label: Label = $Panel/VBoxContainer/DynastyLabel
@onready var name_input: LineEdit = $Panel/VBoxContainer/HBoxContainer/NameInput
@onready var surname_option: OptionButton = $Panel/VBoxContainer/SurnameContainer/SurnameOption
@onready var clan_option: OptionButton = $Panel/VBoxContainer/ClanContainer/ClanOption
@onready var profession_option: OptionButton = $Panel/VBoxContainer/ProfessionContainer/ProfessionOption
@onready var age_slider: HSlider = $Panel/VBoxContainer/AgeContainer/AgeSlider
@onready var age_label: Label = $Panel/VBoxContainer/AgeContainer/AgeLabel
@onready var create_button: Button = $Panel/VBoxContainer/ButtonContainer/CreateButton
@onready var reroll_button: Button = $Panel/VBoxContainer/ButtonContainer/RerollButton
@onready var info_label: Label = $Panel/VBoxContainer/InfoLabel

# ── 百家姓 → 八大姓映射表 ──
# 每个氏（clan）追溯至一个远古姓（surname），用于氏名验证
const CLAN_TO_SURNAME: Dictionary = {
	# ====== 姬姓 — 周王室，黄帝后裔，百家姓最大来源 ======
	"周": "姬", "鲁": "姬", "晋": "姬", "卫": "姬", "郑": "姬", "燕": "姬",
	"吴": "姬", "虢": "姬", "蔡": "姬", "曹": "姬", "霍": "姬",
	"毛": "姬", "郜": "姬", "滕": "姬", "毕": "姬", "原": "姬",
	"丰": "姬", "郇": "姬", "邘": "姬", "应": "姬", "凡": "姬", "胙": "姬",
	"祭": "姬", "共": "姬", "管": "姬", "郄": "姬", "荀": "姬", "知": "姬",
	"随": "姬", "解": "姬", "籍": "姬", "岑": "姬", "邢": "姬", "邵": "姬",
	"贾": "姬", "郤": "姬", "栾": "姬", "卻": "姬", "鄂": "姬", "冉": "姬",
	"邰": "姬", "滑": "姬", "单": "姬", "詹": "姬", "阴": "姬", "狐": "姬",
	"阳": "姬", "南": "姬", "游": "姬", "段": "姬", "温": "姬", "焦": "姬",
	"甘": "姬", "召": "姬", "宁": "姬", "成": "姬", "耿": "姬",
	"弘": "姬", "匡": "姬", "满": "姬", "井": "姬", "养": "姬", "鞠": "姬",
	"逮": "姬", "殳": "姬", "厍": "姬", "空": "姬",
	"王": "姬", "张": "姬", "刘": "姬", "杨": "姬", "郭": "姬", "孙": "姬",
	"魏": "姬", "蒋": "姬", "沈": "姬", "韩": "姬", "冯": "姬", "潘": "姬",
	"于": "姬", "康": "姬", "石": "姬", "阎": "姬", "汪": "姬", "盛": "姬",
	"戚": "姬", "茅": "姬", "庞": "姬", "颜": "姬", "林": "姬", "殷": "姬",
	"常": "姬", "武": "姬", "乔": "姬", "赖": "姬", "龚": "姬", "文": "姬",
	"聂": "姬", "关": "姬", "孟": "姬", "白": "姬", "班": "姬",
	"寇": "姬", "广": "姬", "蔚": "姬", "隆": "姬", "师": "姬",
	"巩": "姬", "辛": "姬", "饶": "姬", "巢": "姬", "蒯": "姬", "后": "姬",
	"荆": "姬", "竺": "姬", "权": "姬", "盖": "姬", "公": "姬",
	"元": "姬", "乌": "姬", "古": "姬", "左": "姬", "司": "姬", "牛": "姬",
	"边": "姬", "那": "姬", "寿": "姬", "步": "姬", "幸": "姬", "曲": "姬",
	"商": "姬", "墨": "姬", "岳": "姬",
	# 姬姓复姓
	"公羊": "姬", "谷梁": "姬", "澹台": "姬", "宗政": "姬", "巫马": "姬",
	"公孙": "姬", "仲孙": "姬", "令狐": "姬", "司徒": "姬", "司空": "姬",
	"端木": "姬", "公西": "姬", "颛孙": "姬", "梁丘": "姬", "东郭": "姬",
	"南门": "姬", "西门": "姬", "南宫": "姬", "东门": "姬", "呼延": "姬",
	"万俟": "姬", "上官": "姬", "夏侯": "姬", "诸葛": "姬", "闻人": "姬",
	"东方": "姬", "赫连": "姬", "皇甫": "姬", "尉迟": "姬", "公冶": "姬",
	"濮阳": "姬", "淳于": "姬", "太叔": "姬", "申屠": "姬", "轩辕": "姬",
	"钟离": "姬", "宇文": "姬", "长孙": "姬", "慕容": "姬", "闾丘": "姬",
	"司寇": "姬", "子车": "姬", "漆雕": "姬", "乐正": "姬", "公良": "姬",
	"夹谷": "姬", "宰父": "姬", "段干": "姬", "百里": "姬", "羊舌": "姬",
	"微生": "姬", "左丘": "姬",
	# ====== 姜姓 — 炎帝后裔，齐国姜氏 ======
	"吕": "姜", "齐": "姜", "许": "姜", "申": "姜", "纪": "姜", "向": "姜",
	"州": "姜", "连": "姜", "丁": "姜", "崔": "姜", "高": "姜", "卢": "姜",
	"柴": "姜", "邱": "姜", "章": "姜", "谢": "姜", "贺": "姜", "骆": "姜",
	"尚": "姜", "查": "姜", "柯": "姜", "薄": "姜", "厉": "姜", "晏": "姜",
	"景": "姜", "雷": "姜", "封": "姜", "钭": "姜", "帅": "姜", "易": "姜",
	"明": "姜", "昌": "姜", "桓": "姜",
	# ====== 姒姓 — 夏禹后裔 ======
	"杞": "姒", "鄫": "姒", "褒": "姒", "莘": "姒", "越": "姒", "夏": "姒",
	"曾": "姒", "谭": "姒", "鲍": "姒", "计": "姒", "窦": "姒", "楼": "姒",
	"欧": "姒", "顾": "姒", "侯": "姒", "娄": "姒", "嵇": "姒", "鱼": "姒",
	"区": "姒", "欧阳": "姒",
	# ====== 妫姓 — 舜帝后裔，陈国 ======
	"陈": "妫", "田": "妫", "胡": "妫", "袁": "妫", "陆": "妫", "薛": "妫",
	"敬": "妫", "车": "妫",
	# ====== 嬴姓 — 伯益后裔，秦国赵氏 ======
	"秦": "嬴", "赵": "嬴", "徐": "嬴", "江": "嬴", "黄": "嬴", "葛": "嬴",
	"梁": "嬴", "谷": "嬴", "廉": "嬴", "马": "嬴", "费": "嬴", "缪": "嬴",
	"奄": "嬴", "钟": "嬴",
	# ====== 姞姓 — 黄帝后裔分支 ======
	"南燕": "姞", "密": "姞", "须": "姞", "雍": "姞", "光": "姞", "阚": "姞",
	"偰": "姞",
	# ====== 妘姓 — 祝融后裔 ======
	"郧": "妘", "邬": "妘", "郐": "妘", "路": "妘", "逼阳": "妘", "夷": "妘",
	"罗": "妘", "董": "妘", "彭": "妘",
	# ====== 姚姓 — 舜帝本姓 ======
	"姚": "姚", "虞": "姚",
}

var _current_attrs: Dictionary = {}
var _inherited_wealth: int = 0
var _class_option: OptionButton = null
var _class_data: Array = []  # [{name, level}]
var _clan_input: LineEdit = null
# ── 出生国选项（西周初期诸侯国）──
# 每个条目: {name: 国名, ruler_surname: 国君姓, desc: 简介}
const BIRTH_STATES: Array = [
	{"name": "周王畿", "ruler_surname": "姬", "desc": "镐京，天子脚下"},
	{"name": "鲁国", "ruler_surname": "姬", "desc": "曲阜，周公旦之嗣"},
	{"name": "齐国", "ruler_surname": "姜", "desc": "临淄，太公望之封"},
	{"name": "晋国", "ruler_surname": "姬", "desc": "唐地，叔虞之邦"},
	{"name": "卫国", "ruler_surname": "姬", "desc": "朝歌，康叔封之国"},
	{"name": "燕国", "ruler_surname": "姬", "desc": "蓟城，召公奭之封"},
	{"name": "蔡国", "ruler_surname": "姬", "desc": "蔡叔度之封"},
	{"name": "曹国", "ruler_surname": "姬", "desc": "曹叔振铎之封"},
	{"name": "虢国", "ruler_surname": "姬", "desc": "王畿之侧，重臣所出"},
	{"name": "吴国", "ruler_surname": "姬", "desc": "江南远藩，太伯之后"},
	{"name": "宋国", "ruler_surname": "子", "desc": "商丘，殷商之后"},
	{"name": "陈国", "ruler_surname": "妫", "desc": "宛丘，舜帝之裔"},
	{"name": "杞国", "ruler_surname": "姒", "desc": "夏禹之后"},
	{"name": "楚国", "ruler_surname": "芈", "desc": "丹阳，南土雄藩"},
	{"name": "许国", "ruler_surname": "姜", "desc": "炎帝后裔，中原小邦"},
	{"name": "申国", "ruler_surname": "姜", "desc": "西陲姜姓重镇"},
	{"name": "纪国", "ruler_surname": "姜", "desc": "东方姜姓古国"},
]

var _clan_validated: bool = false
var _state_option: OptionButton = null
var _reroll_used: bool = false

func _ready() -> void:
	dynasty_label.text = "朝代：西周（公元前1046年——前771年）| 民族：华族"

	# 西周主题样式
	VisualConfig.style_heading_label(dynasty_label, 18)
	VisualConfig.style_button(create_button, 16)

	# 初始化八大姓选择
	surname_option.clear()
	surname_option.add_item("姬")
	surname_option.add_item("姜")
	surname_option.add_item("姒")
	surname_option.add_item("妫")
	surname_option.add_item("嬴")
	surname_option.add_item("姞")
	surname_option.add_item("妘")
	surname_option.add_item("姚")
	surname_option.select(0)
	surname_option.item_selected.connect(_on_surname_changed)

	# 初始化氏 —— 隐藏 OptionButton，替换为 LineEdit 自由输入 + 验证按钮
	clan_option.visible = false
	var clan_hbox := HBoxContainer.new()
	clan_hbox.name = "ClanHBox"
	_clan_input = LineEdit.new()
	_clan_input.name = "ClanInput"
	_clan_input.placeholder_text = "输入氏名（如：周、张、司马）"
	_clan_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clan_hbox.add_child(_clan_input)
	var validate_btn := Button.new()
	validate_btn.name = "ValidateClanBtn"
	validate_btn.text = "验证"
	validate_btn.pressed.connect(_on_validate_clan_pressed)
	VisualConfig.style_button(validate_btn, 14)
	clan_hbox.add_child(validate_btn)
	clan_option.get_parent().add_child(clan_hbox)

	# ── 身份选择器（动态创建）──
	var class_container := HBoxContainer.new()
	class_container.name = "ClassContainer"
	var class_label := Label.new()
	class_label.text = "等级："
	class_container.add_child(class_label)
	_class_option = OptionButton.new()
	_class_option.name = "ClassOption"
	_class_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 从 SOCIAL_CLASSES 加载所有身份级别
	var all_classes: Array = []
	for lvl in range(1, 7):  # 1-6
		if CharacterManager.SOCIAL_CLASSES.has(lvl):
			all_classes.append(CharacterManager.SOCIAL_CLASSES[lvl])

	_class_data = all_classes
	for i in range(all_classes.size()):
		var sc: Dictionary = all_classes[i]
		_class_option.add_item(sc.display)
		# 仅"士"(level 3)可选，其余灰色锁定
		if sc.level != 3:
			_class_option.set_item_disabled(i, true)

	_class_option.select(2)  # index 2 = level 3 = 士
	class_container.add_child(_class_option)

	# 插入到 VBoxContainer 中（在 ClanContainer 之后）
	var vbox: VBoxContainer = $Panel/VBoxContainer
	var clan_idx := clan_option.get_parent().get_index()
	vbox.add_child(class_container)
	vbox.move_child(class_container, clan_idx + 1)

	# ── 出生国选择器 ──
	var state_container := HBoxContainer.new()
	state_container.name = "StateContainer"
	var state_label := Label.new()
	state_label.text = "出生国："
	state_container.add_child(state_label)
	_state_option = OptionButton.new()
	_state_option.name = "StateOption"
	_state_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(BIRTH_STATES.size()):
		var st = BIRTH_STATES[i]
		_state_option.add_item(st.name + "（" + st.ruler_surname + "姓 · " + st.desc + "）")
	_state_option.select(0)  # 默认周王畿
	state_container.add_child(_state_option)
	vbox.add_child(state_container)
	vbox.move_child(state_container, clan_idx + 2)

	# 职业将在16岁成人礼时选择
	profession_option.get_parent().visible = false

	# 年龄——固定0岁开局
	age_slider.visible = false
	age_label.text = "年龄：0岁（新生儿）"

	# 隐藏属性掷骰区域（基础属性自动生成，无需玩家手动掷骰）
	$Panel/VBoxContainer/AttrTitle.visible = false
	$Panel/VBoxContainer/AttrContainer.visible = false
	reroll_button.visible = false

	# 自动生成基础属性（3d6掷骰，不显示给玩家）
	_roll_attributes()

	# 按钮
	create_button.pressed.connect(_on_create_pressed)

func _update_clan_options(_index: int) -> void:
	# 氏改为自由输入（原 OptionButton 已隐藏）
	pass

func _on_surname_changed(index: int) -> void:
	_update_clan_options(index)
	_clan_validated = false  # 换姓后需重新验证
	info_label.text = "姓氏已变更，请重新验证氏名。"

func _validate_clan_basic(clan_text: String) -> String:
	"""基础格式验证，返回错误信息或空字符串"""
	if clan_text.strip_edges().is_empty():
		return "氏名不能为空。"
	if clan_text.length() > 4:
		return "氏名不能超过4个字。"
	for ch in clan_text:
		var code: int = ch.unicode_at(0)
		if code < 0x3400 or code > 0x9FFF:
			if code < 0x4E00 or code > 0x9FFF:
				if ch != "·" and ch != "・":
					return "氏名只能包含汉字。"
	return ""

func _on_validate_clan_pressed() -> void:
	"""验证氏名：先检查格式，再通过百家姓查远古姓"""
	var clan: String = _clan_input.text.strip_edges() if _clan_input else ""
	var basic_error := _validate_clan_basic(clan)
	if not basic_error.is_empty():
		info_label.text = "氏名格式错误：" + basic_error
		_clan_validated = false
		return
	# 查百家姓 → 八大姓映射
	var origin: String = CLAN_TO_SURNAME.get(clan, "")
	if origin.is_empty():
		info_label.text = "\u2717 验证失败：\u300c" + clan + "\u300d不在百家姓中，或无法追溯至八大姓，无法通过。"
		_clan_validated = false
		return
	# 获取当前选中的姓
	var surname_names: Array[String] = ["姬", "姜", "姒", "妫", "嬴", "姞", "妘", "姚"]
	var surname: String = surname_names[surname_option.selected]
	if origin == surname:
		info_label.text = "\u2713 验证通过：\u300c" + clan + "\u300d氏 源自 " + surname + "姓。"
		_clan_validated = true
	else:
		info_label.text = "\u2717 验证失败：\u300c" + clan + "\u300d氏 源自 " + origin + "姓，而非 " + surname + "姓。请更换姓氏后重试。"
		_clan_validated = false


func _roll_attributes() -> void:
	_current_attrs = {
		"con": randi_range(1, 6) + randi_range(1, 6) + randi_range(1, 6),
		"int": randi_range(1, 6) + randi_range(1, 6) + randi_range(1, 6),
		"str": randi_range(1, 6) + randi_range(1, 6) + randi_range(1, 6),
		"cha": randi_range(1, 6) + randi_range(1, 6) + randi_range(1, 6),
		"vir": randi_range(1, 6) + randi_range(1, 6) + randi_range(1, 6),
		"luk": randi_range(1, 6) + randi_range(1, 6) + randi_range(1, 6),
	}
	_inherited_wealth = 30 + randi_range(0, 60)
	# 基础属性自动生成（3d6），不再在界面上显示，直接进入游戏
	info_label.text = "家族遗产：%d 石 | 默认等级：士" % _inherited_wealth

func _on_reroll_pressed() -> void:
	"""重掷骰子，仅限一次"""
	if _reroll_used:
		info_label.text = "重掷次数已用尽。命运已定，请创建角色。"
		return
	_roll_attributes()
	_reroll_used = true
	reroll_button.disabled = true
	reroll_button.text = "已用尽"

func _update_attr_display() -> void:
	var attr_names = ["con", "int", "str", "cha", "vir", "luk"]
	var attr_displays = ["体质", "智力", "武力", "魅力", "德行", "气运"]
	for i in range(attr_names.size()):
		var label = $Panel/VBoxContainer/AttrContainer.get_child(i)
		if label is Label:
			var val = _current_attrs[attr_names[i]]
			var bonus = DiceSystem.attr_to_bonus(val)
			var bonus_str = ""
			if bonus > 0:
				bonus_str = " (+%d)" % bonus
			elif bonus < 0:
				bonus_str = " (%d)" % bonus
			label.text = "%s：%d%s" % [attr_displays[i], val, bonus_str]

	# 更新提示
	var total = 0
	for v in _current_attrs.values():
		total += v
	if total >= 80:
		info_label.text = "天资卓越！这是极为罕见的优秀属性组合。" + (" | 家族遗产：%d 石" % _inherited_wealth)
	elif total >= 70:
		info_label.text = "综合素质不错，适合多种发展路线。" + (" | 家族遗产：%d 石" % _inherited_wealth)
	elif total >= 60:
		info_label.text = "中规中矩的资质，可以胜任士的职责。" + (" | 家族遗产：%d 石" % _inherited_wealth)
	elif total >= 50:
		info_label.text = "资质平平——但历史上许多伟大人物也是如此起步。" + (" | 家族遗产：%d 石" % _inherited_wealth)
	else:
		info_label.text = "命运给你的起点很低——但这正是传奇故事的开端。" + (" | 家族遗产：%d 石" % _inherited_wealth)

func _on_create_pressed() -> void:
	var surnames: Array[String] = ["姬", "姜", "姒", "妫", "嬴", "姞", "妘", "姚"]
	var surname: String = surnames[surname_option.selected]
	var clan: String = _clan_input.text.strip_edges() if _clan_input else ""
	# 自动验证氏名（无需手动点击验证按钮）
	var basic_error := _validate_clan_basic(clan)
	if not basic_error.is_empty():
		info_label.text = "氏名错误：" + basic_error
		return
	var origin: String = CLAN_TO_SURNAME.get(clan, "")
	if origin.is_empty():
		info_label.text = "✗ 「" + clan + "」不在百家姓中，无法追溯至八大姓，请重新输入。"
		return
	if origin != surname:
		info_label.text = "✗ 「" + clan + "」氏 源自 " + origin + "姓，而非 " + surname + "姓。请更换姓氏或修改氏名。"
		return

	var character = CharacterManager.create_character({
		"name": name_input.text if not name_input.text.is_empty() else _random_name(),
		"surname": surname,
		"clan": clan,
		"age": 0,
		"social_class": _class_data[_class_option.selected].name,
		"social_level": _class_data[_class_option.selected].level,
		"birth_state": BIRTH_STATES[_state_option.selected].name,
		"profession": "",
		"gender": "male",  # 西周限定男性；后世朝代可在此扩展性别选择
		"attr_bonus": {}, "starting_wealth": _inherited_wealth,
	})

	character.attributes = _current_attrs
	character.skills = []
	character.derived = CharacterManager._calculate_derived(character)
	GameState.current_character = character

	# 生成父母，继承家族财富
	var parents = CharacterManager.generate_parents(surname)
	GameState.family_data["parents"] = parents
	GameState.family_data.wealth = parents.family_wealth
	# 生成兄弟姐妹
	var siblings = CharacterManager.generate_siblings(surname, parents.father.age, parents.mother.age)
	GameState.family_data["siblings"] = siblings
	character.wealth = parents.family_wealth
	character.derived = CharacterManager._calculate_derived(character)

	# 给用户明确反馈：按钮文字变化，确认正在进入游戏
	create_button.text = "正在进入……"
	create_button.disabled = true
	info_label.text = "✓ 角色创建成功，正在进入西周世界……"

	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _random_name() -> String:
	var names = ["旦", "奭", "鲜", "度", "封", "发", "诵", "钊", "瑕", "满",
				  "伯", "仲", "叔", "季", "孝", "文", "武", "桓", "昭", "穆",
				  "子期", "子产", "子路", "子贡", "子思", "子夏", "子张"]
	return names[randi_range(0, names.size() - 1)]
