# HUD.gd — 主游戏界面HUD（11行动 + 婚姻子女 + 继承人）
extends Control

@onready var year_label: Label = $TopBar/YearLabel
@onready var dynasty_label: Label = $TopBar/DynastyLabel
@onready var location_label: Label = $TopBar/LocationLabel
@onready var season_label: Label = $TopBar/SeasonLabel

@onready var char_name_label: Label = $SidePanel/CharInfo/NameLabel
@onready var char_identity_label: Label = $SidePanel/CharInfo/IdentityLabel
@onready var char_profession_label: Label = $SidePanel/CharInfo/ProfessionLabel
@onready var char_clan_label: Label = $SidePanel/CharInfo/ClanLabel
@onready var char_age_label: Label = $SidePanel/CharInfo/AgeLabel
@onready var char_stage_label: Label = $SidePanel/CharInfo/StageLabel

@onready var health_bar: ProgressBar = $SidePanel/Stats/HealthBar
@onready var reputation_bar: ProgressBar = $SidePanel/Stats/ReputationBar
@onready var power_bar: ProgressBar = $SidePanel/Stats/PowerBar
@onready var ambition_bar: ProgressBar = $SidePanel/Stats/AmbitionBar
@onready var wealth_label: Label = $SidePanel/Stats/WealthLabel

@onready var attrs_label: Label = $SidePanel/Attributes/AttrsLabel
@onready var skills_label: Label = $SidePanel/Skills/SkillsLabel

@onready var event_log: RichTextLabel = $MainArea/EventLog

# 底部11个按钮
@onready var advance_btn: Button = $BottomBar/AdvanceBtn
@onready var work_btn: Button = $BottomBar/WorkBtn
@onready var study_btn: Button = $BottomBar/StudyBtn
@onready var social_btn: Button = $BottomBar/SocialBtn
@onready var marry_btn: Button = $BottomBar/MarryBtn
@onready var ritual_btn: Button = $BottomBar/RitualBtn
@onready var travel_btn: Button = $BottomBar/TravelBtn
@onready var hunt_btn: Button = $BottomBar/HuntBtn
@onready var market_btn: Button = $BottomBar/MarketBtn
@onready var teach_btn: Button = $BottomBar/TeachBtn
@onready var rest_btn: Button = $BottomBar/RestBtn
@onready var menu_btn: Button = $BottomBar/MenuBtn
@onready var ask_parents_btn: Button = $BottomBar/AskParentsBtn
@onready var auto_btn: Button = $BottomBar/AutoBtn

var _main_char_milestones: Array = []
var _auto_mode: bool = false
var _auto_timer: Timer = null

var _cooldowns: Dictionary = {}
var _intimate_this_season: Dictionary = {}   # 本季与哪些妻妾互动过（忠诚衰减豁免）
var _last_work_mode: String = ""    # 记忆上次履职强度（一键复用）
var _last_study_mode: String = ""   # 记忆上次修习方式（一键复用）
var _last_study_skill: String = ""  # 记忆上次修习技能（一键复用）

# 志向系统
const AMBITIONS: Dictionary = {
	"wealth": {
		"name": "富甲一方",
		"desc": "积累财富，达到200石",
		"icon": "💰",
		"check": "wealth",
		"target": 200,
	},
	"power": {
		"name": "位极人臣",
		"desc": "擢升至卿大夫及以上",
		"icon": "👑",
		"check": "social_level",
		"target": 4,
	},
	"fame": {
		"name": "名垂青史",
		"desc": "声望卓著，达到80",
		"icon": "📜",
		"check": "reputation",
		"target": 80,
	},
	"family": {
		"name": "桃李满园",
		"desc": "培养3个子女成年",
		"icon": "🌳",
		"check": "children_adult",
		"target": 3,
	},
	"longevity": {
		"name": "随遇而安",
		"desc": "安然活到50岁",
		"icon": "🧘",
		"check": "age",
		"target": 50,
	},
}
var _ambition_type: String = ""
var _ambition_progress: float = 0.0
var _ambition_achieved: bool = false

# 城市背景 & 角色立绘（_ready 中创建）
var _city_bg_rect: TextureRect = null
var _char_portrait: TextureRect = null

# ============================================================
# 初始化
# ============================================================
func _ready() -> void:
	advance_btn.pressed.connect(_on_advance_time)
	work_btn.pressed.connect(_on_work)
	study_btn.pressed.connect(_on_study)
	social_btn.pressed.connect(_on_socialize)
	marry_btn.pressed.connect(_on_marry)
	ritual_btn.pressed.connect(_on_ritual)
	travel_btn.pressed.connect(_on_travel)
	hunt_btn.pressed.connect(_on_hunt)
	market_btn.pressed.connect(_on_market)
	teach_btn.pressed.connect(_on_teach_child)
	rest_btn.pressed.connect(_on_rest)
	menu_btn.pressed.connect(_on_menu)
	ask_parents_btn.pressed.connect(_on_ask_parents)
	auto_btn.pressed.connect(_on_toggle_auto)

	_auto_timer = Timer.new()
	_auto_timer.one_shot = false
	_auto_timer.wait_time = 1.2
	_auto_timer.timeout.connect(_on_auto_tick)
	add_child(_auto_timer)

	# ============================================================
	# 西周主题 — 城市背景层
	# ============================================================
	_city_bg_rect = TextureRect.new()
	_city_bg_rect.name = "CityBackground"
	_city_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_city_bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_city_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_city_bg_rect.modulate = Color(0.25, 0.25, 0.25, 0.5)  # 暗色叠加
	_city_bg_rect.anchor_left = 0.22
	_city_bg_rect.anchor_top = 0.06
	_city_bg_rect.anchor_right = 1.0
	_city_bg_rect.anchor_bottom = 1.0
	_city_bg_rect.offset_left = 0
	_city_bg_rect.offset_top = 0
	_city_bg_rect.offset_right = -10
	_city_bg_rect.offset_bottom = -60
	add_child(_city_bg_rect)
	move_child(_city_bg_rect, 1)  # 放在 Background ColorRect 之上

	# ============================================================
	# 西周主题 — 角色立绘
	# ============================================================
	_char_portrait = TextureRect.new()
	_char_portrait.name = "CharPortrait"
	_char_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_char_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_char_portrait.custom_minimum_size = Vector2(180, 240)
	_char_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 插入 SidePanel/CharInfo 最前面
	var char_info = $SidePanel/CharInfo
	char_info.add_child(_char_portrait)
	char_info.move_child(_char_portrait, 0)

	# ============================================================
	# 西周主题 — 应用 VisualConfig 样式
	# ============================================================
	VisualConfig.style_title_label(char_name_label, 20)
	VisualConfig.style_body_label(char_identity_label, 13)
	VisualConfig.style_body_label(char_profession_label, 13)
	VisualConfig.style_small_label(char_clan_label, 12)
	VisualConfig.style_body_label(char_age_label, 13)
	VisualConfig.style_small_label(char_stage_label, 12)
	VisualConfig.style_body_label(wealth_label, 14)

	# 按钮统一样式
	var all_btns := [
		advance_btn, work_btn, study_btn, social_btn, marry_btn,
		ritual_btn, travel_btn, hunt_btn, market_btn, teach_btn,
		rest_btn, menu_btn, ask_parents_btn, auto_btn
	]
	var btn_styles := VisualConfig.get_button_stylebox()   # U-3 共享缓存，避免40+ StyleBox 实例
	for btn in all_btns:
		VisualConfig.style_button(btn, 13)
		btn.add_theme_stylebox_override("normal", btn_styles["normal"])
		btn.add_theme_stylebox_override("hover", btn_styles["hover"])
		btn.add_theme_stylebox_override("pressed", btn_styles["pressed"])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # U-4 均分剩余空间，防溢出
		_bind_feedback(btn)

	# 进度条应用纯色样式（按语义配色，无需纹理）
	VisualConfig.style_progress_bar(health_bar, VisualConfig.BAR_HEALTH)
	VisualConfig.style_progress_bar(reputation_bar, VisualConfig.BAR_REPUTATION)
	VisualConfig.style_progress_bar(power_bar, VisualConfig.BAR_POWER)
	VisualConfig.style_progress_bar(ambition_bar, VisualConfig.BAR_AMBITION)

	# ── 按钮分类整理 ──
	_setup_category_buttons()

	# 家兵标签——动态添加到状态区
	var stats_box = $SidePanel/Stats
	_troops_label = Label.new()
	_troops_label.name = "TroopsLabel"
	VisualConfig.style_body_label(_troops_label, 14)
	stats_box.add_child(_troops_label)

	# 募兵按钮——动态添加到按钮栏
	_recruit_troops_btn = Button.new()
	_recruit_troops_btn.name = "RecruitTroopsBtn"
	_recruit_troops_btn.text = "⚔ 募兵"
	_recruit_troops_btn.custom_minimum_size = Vector2(90, 32)
	VisualConfig.style_button(_recruit_troops_btn, 13)
	var rt_styles := VisualConfig.get_button_stylebox()   # U-3 共享缓存
	_recruit_troops_btn.add_theme_stylebox_override("normal", rt_styles["normal"])
	_recruit_troops_btn.add_theme_stylebox_override("hover", rt_styles["hover"])
	_recruit_troops_btn.add_theme_stylebox_override("pressed", rt_styles["pressed"])
	_recruit_troops_btn.pressed.connect(_on_recruit_troops)
	_recruit_troops_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # U-4 均分，防溢出
	_bind_feedback(_recruit_troops_btn)
	var bb = $BottomBar
	bb.add_child(_recruit_troops_btn)
	bb.move_child(_recruit_troops_btn, rest_btn.get_index())

	_refresh_display()
	_age_gate_buttons()
	_add_log("西周%d年，%s%s·%s氏作为%s，在镐京开始了他的生涯……" % [
		abs(GameState.current_year),
		GameState.current_character.surname,
		GameState.current_character.get("name", ""),
		GameState.current_character.get("clan", ""),
		GameState.current_character.get("profession", "士")
	])

	# 重构侧边栏为可折叠区域
	_build_side_panel()

	# 0岁开局：弹出童年快进选项
	var age0 = CharacterManager.get_character_age(GameState.current_character)
	if age0 == 0:
		_show_childhood_fast_forward()

	# 订阅季节变化信号（P3-1 季节转场动画）
	TimeManager.season_changed.connect(_on_season_changed)

	# P1-6 首次进入新手引导（叙事口吻，纯 UI 层）
	_start_tutorial()

# ============================================================
# P1-6 新手引导（首次进入 3 步，纯 UI 层）
# ============================================================
var _tutorial_step: int = 0
var _tutorial_done: bool = false
var _tutorial_highlight: Tween = null

func _start_tutorial() -> void:
	if _tutorial_done or GameState.tutorial_done:
		return
	_tutorial_step = 1
	_show_tutorial_step()

func _show_tutorial_step() -> void:
	_clear_tutorial_highlight()
	var target: Control = null
	var tip: String = ""
	match _tutorial_step:
		1:
			target = $TopBar
			tip = "这是你的家族纪年栏——年份、朝代、季节都在这里流转。"
		2:
			target = advance_btn
			tip = "春去秋来，点击「推进」度过一季，人生由此展开。"
		3:
			target = _category_btns.get("career") as Control
			tip = "打开「仕途」，选择「履职」赚取俸禄，方能安身立命。"
	if target == null:
		_tutorial_done = true
		GameState.tutorial_done = true
		return
	var popup := _make_popup("TutorialTip", 230, 140)
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, "📖 入门指引 %d/3" % _tutorial_step)
	var info := Label.new()
	info.text = tip
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)
	var next := Button.new()
	next.text = "明白了"
	next.custom_minimum_size = Vector2(0, 34)
	next.pressed.connect(func():
		popup.queue_free()
		_clear_tutorial_highlight()
		_tutorial_step += 1
		if _tutorial_step <= 3:
			_show_tutorial_step()
		else:
			_tutorial_done = true
			GameState.tutorial_done = true
	)
	vbox.add_child(next)
	add_child(popup)
	# 目标控件高亮闪烁
	_tutorial_highlight = create_tween().set_loops()
	_tutorial_highlight.tween_property(target, "modulate", Color(1.4, 1.4, 1.0), 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tutorial_highlight.tween_property(target, "modulate", Color.WHITE, 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _clear_tutorial_highlight() -> void:
	if _tutorial_highlight != null:
		_tutorial_highlight.kill()
		_tutorial_highlight = null
	for c in [$TopBar, advance_btn]:
		c.modulate = Color.WHITE
	if _category_btns.has("career"):
		_category_btns.career.modulate = Color.WHITE

# ============================================================
# P3 动画：季节转场 / 立绘呼吸 / 死亡转场
# ============================================================
const SEASON_TINTS := {
	TimeManager.Season.SPRING: Color(0.55, 1.0, 0.55, 0.12),
	TimeManager.Season.SUMMER: Color(1.0, 0.9, 0.55, 0.10),
	TimeManager.Season.AUTUMN: Color(1.0, 0.72, 0.35, 0.14),
	TimeManager.Season.WINTER: Color(0.65, 0.8, 1.0, 0.16),
}

var _portrait_idle: Tween = null

func _on_season_changed(_old: int, new_season: int, _year: int) -> void:
	_play_season_transition(new_season)

func _play_season_transition(new_season: int) -> void:
	# 季节色调滤镜淡入淡出（复用 TWEEN_SEASON 常量，零新资源）
	var tint: Color = SEASON_TINTS.get(new_season, Color.TRANSPARENT)
	var overlay := ColorRect.new()
	overlay.color = Color(tint.r, tint.g, tint.b, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var tw := create_tween()
	tw.tween_property(overlay, "color:a", tint.a, 0.25)
	tw.tween_property(overlay, "color:a", 0.0, VisualConfig.TWEEN_SEASON)
	tw.tween_callback(overlay.queue_free)

func _start_portrait_idle() -> void:
	# 立绘待机"呼吸"：用 scale+modulate 而非 position（VBox 布局会顶回 position tween）
	if _char_portrait == null or _portrait_idle != null:
		return
	_char_portrait.pivot_offset = _char_portrait.size * 0.5
	_char_portrait.pivot_offset = Vector2(90, 120)
	_portrait_idle = create_tween().set_loops()
	_portrait_idle.tween_property(_char_portrait, "scale", Vector2(1.015, 1.015), 1.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_portrait_idle.tween_property(_char_portrait, "scale", Vector2.ONE, 1.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _play_death_transition(then: Callable) -> void:
	# 死亡戏剧化转场：深红→全黑（复用 TWEEN_DEATH 常量）
	var veil := ColorRect.new()
	veil.color = Color(0.10, 0.0, 0.0, 0.0)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var tw := create_tween()
	tw.tween_property(veil, "color:a", 1.0, VisualConfig.TWEEN_DEATH)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(then)

# ============================================================
# 工具
# ============================================================
func _season_key() -> String:
	return "%d_%d" % [GameState.current_year, TimeManager.current_season]

func _can_act(id: String) -> bool:
	return _cooldowns.get(id, "") != _season_key()

func _mark_acted(id: String) -> void:
	_cooldowns[id] = _season_key()

func _mark_intimate(mother_type: String, mother_index: int) -> void:
	"""标记本季与某妻妾互动过（交谈/亲近/赏赐/求子）——忠诚衰减豁免"""
	_intimate_this_season["%s_%d" % [mother_type, mother_index]] = true

func _is_intimate(mother_type: String, mother_index: int) -> bool:
	return _intimate_this_season.get("%s_%d" % [mother_type, mother_index], false)

func _find_consort_index(mother_type: String, member_data: Dictionary) -> int:
	"""按名字找妻妾在列表中的索引（wife 恒为 0）"""
	if mother_type == "wife":
		return 0
	var arr: Array = []
	match mother_type:
		"concubine": arr = GameState.family_data.get("concubines", [])
		"furen": arr = GameState.family_data.get("furens", [])
		"ying_qie": arr = GameState.family_data.get("ying_qie", [])
		"tongfang": arr = GameState.family_data.get("tongfangs", [])
	for i in range(arr.size()):
		if arr[i].name == member_data.name and arr[i].surname == member_data.surname:
			return i
	return -1

func _run_family_act(id: String, log: String, cb: Callable) -> void:
	"""统一家族动作执行器：入口查冷却，执行后打点"""
	if not id.is_empty() and not _can_act(id):
		_add_log(log)
		return
	cb.call()
	if not id.is_empty():
		_mark_acted(id)

# ============================================================
# 快捷键：空格=推进，1=履职，2=修习（P1-4）
# 用 _input 在 GUI 消费前拦截；输入框聚焦或弹窗开启时不响应
# ============================================================
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# 输入框聚焦时按键用于输入，不触发快捷键
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	# 有弹窗/事件对话框开启时不响应（避免在对白中误推进）
	if _has_modal_open():
		return
	match event.keycode:
		KEY_SPACE:
			_on_advance_time()
			get_viewport().set_input_as_handled()
		KEY_1:
			_work_quick()
			get_viewport().set_input_as_handled()
		KEY_2:
			_study_quick()
			get_viewport().set_input_as_handled()

func _has_modal_open() -> bool:
	# 检测是否有关键弹窗（CanvasLayer 弹层）或事件对话框开启
	if _category_popup != null and is_instance_valid(_category_popup):
		return true
	for child in get_children():
		if child is CanvasLayer:
			return true
		if child.name == "EventDialog" or child is Control and child.get_script() != null and str(child.get_script()).contains("event_dialog"):
			return true
	return false

# ============================================================
# 按钮分类系统 — 将14个按钮归类为5个入口
# ============================================================
# 可折叠区域
var _accordion_scroll: ScrollContainer = null
var _accordion_vbox: VBoxContainer = null
var _section_headers: Dictionary = {}   # section_name -> Button
var _section_contents: Dictionary = {}  # section_name -> VBoxContainer
var _family_vbox: VBoxContainer = null   # 家族内容容器

var _category_btns: Dictionary = {}
var _troops_label: Label = null
var _recruit_troops_btn: Button = null
var _category_popup: CanvasLayer = null
var _daily_btn: Button = null   # 一键日常按钮

# ============================================================
# 可折叠侧边栏 — ScrollContainer + 折叠头部
# ============================================================
func _make_accordion_section(title: String) -> Dictionary:
	"""创建可折叠区域：返回 {header: Button, content: VBoxContainer}"""
	var header := Button.new()
	header.text = "\u25bc " + title
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.custom_minimum_size = Vector2(0, 26)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	VisualConfig.style_button(header, 12)
	header.add_theme_color_override("font_color", VisualConfig.DARK_GOLD)
	header.add_theme_color_override("font_hover_color", VisualConfig.GOLD)
	# Flat header style
	var hb_style := StyleBoxFlat.new()
	hb_style.bg_color = VisualConfig.BG_MID_BROWN
	hb_style.border_width_bottom = 1
	hb_style.border_color = VisualConfig.BRONZE
	hb_style.content_margin_left = 6
	hb_style.content_margin_top = 3
	hb_style.content_margin_bottom = 3
	header.add_theme_stylebox_override("normal", hb_style)
	var hb_hover := hb_style.duplicate() as StyleBoxFlat
	hb_hover.bg_color = VisualConfig.BRONZE_GREEN_DARK
	header.add_theme_stylebox_override("hover", hb_hover)

	var content := VBoxContainer.new()
	content.name = title + "_Content"
	content.add_theme_constant_override("separation", 3)

	header.pressed.connect(func():
		var is_visible := content.visible
		content.visible = not is_visible
		header.text = ("\u25bc " if not is_visible else "\u25b6 ") + title
	)

	return {"header": header, "content": content}


func _build_side_panel() -> void:
	"""将 SidePanel 重构为 ScrollContainer + 可折叠区域"""
	var sp = $SidePanel

	# 收集并移除现有子节点（保留引用）
	var char_info := sp.get_node("CharInfo") as VBoxContainer
	var sep1 := sp.get_node("Sep1") as HSeparator
	var stats := sp.get_node("Stats") as VBoxContainer
	var sep2 := sp.get_node("Sep2") as HSeparator
	var attrs := sp.get_node("Attributes") as VBoxContainer
	var sep3 := sp.get_node("Sep3") as HSeparator
	var skills := sp.get_node("Skills") as VBoxContainer

	# 移除所有子节点（暂存）
	for child in sp.get_children():
		sp.remove_child(child)

	# 删除分隔线
	sep1.queue_free()
	sep2.queue_free()
	sep3.queue_free()

	# 创建 ScrollContainer
	_accordion_scroll = ScrollContainer.new()
	_accordion_scroll.name = "AccordionScroll"
	_accordion_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_accordion_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_accordion_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sp.add_child(_accordion_scroll)

	# 内部 VBox
	_accordion_vbox = VBoxContainer.new()
	_accordion_vbox.name = "AccordionVBox"
	_accordion_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_accordion_vbox.add_theme_constant_override("separation", 0)
	_accordion_scroll.add_child(_accordion_vbox)

	# ── 区域1: 角色信息（默认展开）──
	var sec1 = _make_accordion_section("角色")
	_section_headers["char"] = sec1.header
	_section_contents["char"] = sec1.content
	_accordion_vbox.add_child(sec1.header)
	_accordion_vbox.add_child(sec1.content)
	sec1.content.add_child(char_info)

	# ── 区域2: 状态数值（默认展开）──
	var sec2 = _make_accordion_section("状态")
	_section_headers["stats"] = sec2.header
	_section_contents["stats"] = sec2.content
	_accordion_vbox.add_child(sec2.header)
	_accordion_vbox.add_child(sec2.content)
	sec2.content.add_child(stats)

	# ── 区域3: 六维属性（默认折叠）──
	var sec3 = _make_accordion_section("属性")
	_section_headers["attrs"] = sec3.header
	_section_contents["attrs"] = sec3.content
	_accordion_vbox.add_child(sec3.header)
	_accordion_vbox.add_child(sec3.content)
	sec3.content.add_child(attrs)
	sec3.content.visible = false
	sec3.header.text = "\u25b6 属性"

	# ── 区域4: 技能（默认折叠）──
	var sec4 = _make_accordion_section("技能")
	_section_headers["skills"] = sec4.header
	_section_contents["skills"] = sec4.content
	_accordion_vbox.add_child(sec4.header)
	_accordion_vbox.add_child(sec4.content)
	sec4.content.add_child(skills)
	sec4.content.visible = false
	sec4.header.text = "\u25b6 技能"

	# ── 区域5: 家族（默认折叠）──
	var sec5 = _make_accordion_section("家族")
	_section_headers["family"] = sec5.header
	_section_contents["family"] = sec5.content
	_accordion_vbox.add_child(sec5.header)
	_accordion_vbox.add_child(sec5.content)
	sec5.content.visible = false
	sec5.header.text = "\u25b6 家族"

	# 家族内容容器
	_family_vbox = VBoxContainer.new()
	_family_vbox.name = "FamilyContent"
	_family_vbox.add_theme_constant_override("separation", 2)
	sec5.content.add_child(_family_vbox)


func _setup_category_buttons() -> void:
	"""隐藏独立按钮，创建分类入口"""
	var bb: HBoxContainer = $BottomBar

	# 清理旧的分类按钮，防止重复创建
	for key in _category_btns:
		var old_btn = _category_btns[key]
		if is_instance_valid(old_btn):
			old_btn.queue_free()
	_category_btns.clear()
	if _daily_btn and is_instance_valid(_daily_btn):
		_daily_btn.queue_free()
		_daily_btn = null

	# 隐藏独立按钮（保留推进/自动/休憩/菜单）
	var hide_list := [work_btn, study_btn, social_btn, marry_btn,
		ritual_btn, travel_btn, hunt_btn, market_btn, teach_btn, ask_parents_btn]
	for btn in hide_list:
		btn.visible = false

	# 创建分类按钮，插入 BottomBar（在 auto_btn 之后）
	var categories := [
		{"text": "💼 仕途", "id": "career", "actions": ["work", "study", "social", "ask_parents"]},
		{"text": "👥 社交", "id": "social", "actions": ["marry", "teach", "ritual"]},
		{"text": "🏠 家庭", "id": "household", "actions": ["household"]},
		{"text": "🗺 出行", "id": "travel", "actions": ["travel", "hunt", "market"]},
	]

	var insert_pos := auto_btn.get_index() + 1

	# ── 一键日常按钮（放在分类按钮最前）──
	_daily_btn = Button.new()
	_daily_btn.name = "DailyRoutineBtn"
	_daily_btn.text = "⚡ 一键日常"
	_daily_btn.custom_minimum_size = Vector2(90, 32)
	_daily_btn.tooltip_text = "一键完成本季可做的履职/修习/交游/祭祀/田猎等日常"
	VisualConfig.style_button(_daily_btn, 13)
	var dl_styles := VisualConfig.make_button_stylebox()
	_daily_btn.add_theme_stylebox_override("normal", dl_styles["normal"])
	_daily_btn.add_theme_stylebox_override("hover", dl_styles["hover"])
	_daily_btn.add_theme_stylebox_override("pressed", dl_styles["pressed"])
	_daily_btn.pressed.connect(_run_daily_routine)
	_bind_feedback(_daily_btn)
	bb.add_child(_daily_btn)
	bb.move_child(_daily_btn, insert_pos)
	insert_pos += 1

	for cat in categories:
		var btn := Button.new()
		btn.name = "CatBtn_" + cat.id
		btn.text = cat.text
		btn.custom_minimum_size = Vector2(90, 32)
		VisualConfig.style_button(btn, 13)
		var btn_styles := VisualConfig.make_button_stylebox()
		btn.add_theme_stylebox_override("normal", btn_styles["normal"])
		btn.add_theme_stylebox_override("hover", btn_styles["hover"])
		btn.add_theme_stylebox_override("pressed", btn_styles["pressed"])
		btn.pressed.connect(_on_category_pressed.bind(cat.id, cat.actions))
		bb.add_child(btn)
		bb.move_child(btn, insert_pos)
		_category_btns[cat.id] = btn
		insert_pos += 1


# ============================================================
# 按钮反馈 & 一键日常
# ============================================================
func _flash_btn(btn: Button) -> void:
	"""按钮按下反馈——轻微缩放 + 金色高亮"""
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size / 2.0
	btn.scale = Vector2(0.94, 0.94)
	btn.modulate = Color(1.4, 1.35, 1.2, 1.0)
	var tween := create_tween()
	tween.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(btn, "modulate", Color.WHITE, 0.2)


func _bind_feedback(btn: Button) -> void:
	"""为持久按钮绑定按下/hover 反馈（U-3：轻量缩放动效）"""
	if not is_instance_valid(btn):
		return
	if btn.has_meta("fb_bound"):
		return
	btn.set_meta("fb_bound", true)
	btn.button_down.connect(_flash_btn.bind(btn))
	btn.pivot_offset = btn.size * 0.5
	btn.mouse_entered.connect(func(): _pulse_btn(btn, 1.03, VisualConfig.TWEEN_HOVER))
	btn.mouse_exited.connect(func(): _pulse_btn(btn, 1.0, VisualConfig.TWEEN_HOVER))
	btn.button_down.connect(func(): _pulse_btn(btn, 0.96, VisualConfig.TWEEN_PRESS))
	btn.button_up.connect(func(): _pulse_btn(btn, 1.0, VisualConfig.TWEEN_PRESS))

func _pulse_btn(btn: Button, target: float, dur: float) -> void:
	if not is_instance_valid(btn):
		return
	btn.pivot_offset = btn.size * 0.5
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", Vector2(target, target), dur)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _run_daily_routine() -> void:
	"""一键日常——自动完成本季可做的全部日常操作"""
	if _category_popup:
		_category_popup.queue_free()
		_category_popup = null
	if advance_btn.disabled or has_node("ChildhoodSkip") or has_node("ComingOfAge"):
		_add_log("当前有重要抉择待定，暂不可一键日常。")
		return
	var char = GameState.current_character
	if char.is_empty() or not char.get("is_alive", true):
		_add_log("当前无法进行日常操作。")
		return
	var age = CharacterManager.get_character_age(char)
	var done: Array[String] = []
	# 1. 履职（正常模式）
	if _can_act("work") and age >= 16 and not char.get("profession", "").is_empty():
		_on_work_execute("normal", null)
		done.append("履职")
	# 2. 修习（自学 + 首个未满技能）
	if _can_act("study") and age >= 6:
		var skill_to_study := ""
		var char_skills: Array = char.get("skills", [])
		for skill_full in CharacterManager.SKILLS:
			var lvl = 0
			for s in char_skills:
				if s.begins_with(skill_full + ":"):
					lvl = int(s.split(":")[1])
			if lvl < 5:
				skill_to_study = skill_full
				break
		if not skill_to_study.is_empty():
			_study_bonus = 0  # 自学模式
			_on_skill_selected(skill_to_study, null)
			done.append("修习")
	# 3. 交游（同僚，稳妥）
	if _can_act("socialize") and age >= 16:
		_on_socialize_execute("colleague", null)
		done.append("交游")
	# 4. 祭祀（心祭，免费）
	if _can_act("ritual") and age >= 16:
		_on_ritual_execute(0, "simple", null)
		done.append("祭祀")
	# 5. 田猎
	if _can_act("hunt") and age >= 16:
		_on_hunt()
		done.append("田猎")
	# 6. 教子（首个在世子女 · 书数）
	var children = CharacterManager.get_character_children(char)
	var teach_idx := -1
	for i in range(children.size()):
		if children[i].get("is_alive", true):
			teach_idx = i
			break
	if _can_act("teach") and teach_idx >= 0:
		_on_teach_subject(teach_idx, "书数", null)
		done.append("教子")
	# 7. 休憩（健康偏低时）
	var health = char.get("derived", {}).get("health", 100)
	if _can_act("rest") and health < 70:
		_on_rest()
		done.append("休憩")
	if done.is_empty():
		_add_log("⚡ 一键日常——本季可做的日常皆已做完。")
	else:
		_add_log("⚡ 一键日常完成：%s。" % "、".join(done))
	_refresh_display()


func _on_category_pressed(cat_id: String, actions: Array) -> void:
	"""点击分类按钮 — 弹出子操作菜单"""
	if _category_popup:
		_category_popup.queue_free()
		_category_popup = null
		# 继续创建新弹窗，不再直接返回

	# 预计算条件按钮数量（仅仕途分类显示晋升按钮）
	var extra_count := 0
	var char_for_cat := GameState.current_character
	if cat_id == "career" and not char_for_cat.is_empty():
		extra_count += 1   # 晋升之门（始终显示，资格可视）
		if char_for_cat.social_level <= 3:
			extra_count += 2   # 耕作/从军
		if char_for_cat.social_level >= 3 and not _attended_court_this_season:
			extra_count += 1   # 朝觐
		if char_for_cat.reputation >= 90 and char_for_cat.social_level >= 3 and char_for_cat.social_level < 6 and not _met_king_this_season:
			extra_count += 1
		if char_for_cat.ambition >= 70 and char_for_cat.social_level < 6 and not _ambition_plotted:
			extra_count += 1

	var total_actions := actions.size() + extra_count
	var popup := _make_popup("CatMenu", 100, 60 + total_actions * 32)
	_category_popup = popup
	var vbox := _popup_vbox(popup)
	var panel: Panel = popup.get_child(1)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	var _ph: int = 60 + total_actions * 32
	panel.offset_top = -(_ph + 20)
	panel.offset_bottom = 60
	panel.offset_left = -100
	panel.offset_right = 100

	for action in actions:
		var action_btn: Button = null
		match action:
			"work": action_btn = _make_action_btn("💼 履职", _on_work, "work")
			"study": action_btn = _make_action_btn("📚 修习", _on_study, "study")
			"social": action_btn = _make_action_btn("🨝 交游", _on_socialize, "social")
			"ask_parents": action_btn = _make_action_btn("💰 要钱", _on_ask_parents, "ask_parents")
			"marry": action_btn = _make_action_btn("💍 议亲", _on_marry, "marry")
			"teach": action_btn = _make_action_btn("👨‍🏫 教子", _on_teach_child, "teach")
			"ritual": action_btn = _make_action_btn("🏛 祭祀", _on_ritual, "ritual")
			"travel": action_btn = _make_action_btn("🗺 出行", _on_travel, "travel")
			"hunt": action_btn = _make_action_btn("🏹 田猎", _on_hunt, "hunt")
			"market": action_btn = _make_action_btn("📦 市集", _on_market, "market")
		if action_btn:
			vbox.add_child(action_btn)

	if cat_id == "career" and not char_for_cat.is_empty():
		# 晋升之门（四道门资格可视 + 正式请迁）
		var gate_btn := _make_action_btn("🗝 晋升之门", _show_promotion_gate)
		vbox.add_child(gate_btn)
		# 国人生计线：耕作/从军（庶人、士可用）
		if char_for_cat.social_level <= 3:
			var farm_btn := _make_action_btn("🌾 耕作（声望+石）", _do_farming, "farm_season")
			vbox.add_child(farm_btn)
			var mil_btn := _make_action_btn("⚔ 从军（军功+1）", _do_military_service, "military_season")
			vbox.add_child(mil_btn)
		# 朝觐按钮（士及以上，每季一次）
		if char_for_cat.social_level >= 3 and not _attended_court_this_season:
			var court_btn := _make_action_btn("🏛 朝觐周王", _on_attend_court)
			vbox.add_child(court_btn)
		if char_for_cat.reputation >= 90 and char_for_cat.social_level >= 3 and char_for_cat.social_level < 6 and not _met_king_this_season:
			var mk_btn := _make_action_btn("👑 觐见国君", _on_meet_king)
			vbox.add_child(mk_btn)
		if char_for_cat.ambition >= 70 and char_for_cat.social_level < 6 and not _ambition_plotted:
			var ab_btn := _make_action_btn("🌑 暗谋举事（铤而走险）", _on_ambition_plot)
			vbox.add_child(ab_btn)

	# 家庭分类——查看家庭成员与和睦
	if cat_id == "household" and not char_for_cat.is_empty():
		_show_household_panel()
		return

	# 社交分类——偷情按钮（已婚成年）
	if cat_id == "social" and not char_for_cat.is_empty():
			var is_adult = CharacterManager.get_character_age(char_for_cat) >= 16
			if is_adult and CharacterManager.is_married(char_for_cat):
				var conc_info = CharacterManager.can_take_concubine(char_for_cat)
				if conc_info.get("can", false):
					var conc_btn := _make_action_btn("💍 纳妾 (%d/%d)" % [conc_info.current, conc_info.max_count], _on_take_concubine)
					vbox.add_child(conc_btn)
				var tf_info = CharacterManager.can_take_tongfang(char_for_cat)
				if tf_info.get("can", false):
					var tf_btn := _make_action_btn("🌸 收通房 (%d/%d)" % [tf_info.current, tf_info.max_count], _on_take_tongfang)
					vbox.add_child(tf_btn)
			var furen_info = CharacterManager.can_take_furen(char_for_cat)
			if furen_info.get("can", false):
				var fr_btn := _make_action_btn("👑 册立夫人 (%d/%d)" % [furen_info.current, furen_info.max_count], _on_take_furen)
				vbox.add_child(fr_btn)
			if is_adult and CharacterManager.is_married(char_for_cat):
				var af_btn := _make_action_btn("🌙 私会（偷情）", _on_start_affair)
				vbox.add_child(af_btn)
	add_child(popup)

func _make_action_btn(text: String, callback: Callable, action_id: String = "") -> Button:
	"""创建分类弹窗中的操作按钮；action_id 非空时按本季冷却置灰标记"""
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(160, 30)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	VisualConfig.style_button(btn, 13)
	var btn_styles := VisualConfig.get_button_stylebox()   # U-3 共享缓存
	btn.add_theme_stylebox_override("normal", btn_styles["normal"])
	btn.add_theme_stylebox_override("hover", btn_styles["hover"])
	btn.add_theme_stylebox_override("pressed", btn_styles["pressed"])
	if not action_id.is_empty() and not _can_act(action_id):
		btn.disabled = true
		btn.text += "  ✓本季已做"
	btn.pressed.connect(func():
		if _category_popup:
			_category_popup.queue_free()
			_category_popup = null
		callback.call()
	)
	return btn


func _age_gate_buttons() -> void:
	var char = GameState.current_character
	if char.is_empty():
		return
	var age = CharacterManager.get_character_age(char)
	var is_adult = age >= 16
	var can_study = age >= 6
	var can_ask_parents = false
	var is_separated = char.get("_separated", false)
	if GameState.family_data.has("parents") and not is_separated:
		var p = GameState.family_data.parents
		var fa = p.father.get("is_alive", false)
		var ma = p.mother.get("is_alive", false)
		can_ask_parents = (fa or ma) and p.get("family_wealth", 0) > 0 and age < 20

	# 主按钮始终可用
	advance_btn.disabled = false
	rest_btn.disabled = false
	menu_btn.disabled = false
	auto_btn.disabled = false

	# 更新独立按钮状态（用于分类弹窗中的按钮引用）
	ask_parents_btn.visible = can_ask_parents
	study_btn.disabled = not can_study
	work_btn.disabled = not is_adult
	social_btn.disabled = not is_adult
	marry_btn.disabled = not is_adult
	ritual_btn.disabled = not is_adult
	travel_btn.disabled = not is_adult
	hunt_btn.disabled = not is_adult
	market_btn.disabled = not is_adult
	teach_btn.disabled = not is_adult

	# 更新分类按钮启用状态
	if _category_btns.has("career"):
		_category_btns.career.disabled = false  # 修习6岁可用，其他16岁
	if _category_btns.has("travel"):
		_category_btns.travel.disabled = not is_adult
	if _category_btns.has("social"):
		_category_btns.social.disabled = not is_adult


const LOG_UI_MAX_LINES := 200        # UI 日志最多显示 200 行（环形缓冲，锁死内存）
const LOG_FULL_MAX_LINES := 5000     # 完整史册硬上限（防存档无限膨胀）

func _add_log(text: String, level: String = "") -> void:
	# 日志分级：未显式指定时按内容自带表情符自动分级
	if level.is_empty():
		if text.begins_with("☠") or text.begins_with("⚰") or text.begins_with("💔") or text.begins_with("📉"):
			level = "danger"
		elif text.begins_with("⚠"):
			level = "warn"
		elif text.begins_with("🎊") or text.begins_with("👶") or text.begins_with("🎓") or text.begins_with("👑"):
			level = "success"
	var color: String = {
		"info": "#d2c4a7",     # 沙土色 — 日常
		"success": "#8fbc8f",  # 铜锈浅绿 — 成长
		"warn": "#daa520",     # 鎏金 — 警告
		"danger": "#c41e3a",   # 朱砂 — 危险/死亡
	}.get(level, "#d2c4a7")
	# 用全角括号作头部，避免裸 ASCII `[` 被 bbcode 解析器误吞
	var line := "[color=%s]〔%s·%d年〕%s[/color]\n" % [
		color, TimeManager.get_season_name(), abs(GameState.current_year), text
	]
	# 完整史册：存"实际 append 的最终字符串"，读档直接回填（与显示一致）
	GameState.full_log.append(line)
	if GameState.full_log.size() > LOG_FULL_MAX_LINES:
		GameState.full_log = GameState.full_log.slice(-LOG_FULL_MAX_LINES)
	# UI 环形缓冲：保留最近 200 行，删除最早段落（延迟一帧规避瞬时跳动）
	event_log.append_text(line)
	call_deferred("_trim_log")

func _trim_log() -> void:
	while event_log.get_paragraph_count() > LOG_UI_MAX_LINES:
		event_log.remove_paragraph(0)

func _on_ask_parents() -> void:
	if not _can_act("ask_parents"):
		_add_log("本季已向父母要过钱，下季再来吧。")
		return
	var char = GameState.current_character
	var age = CharacterManager.get_character_age(char)
	if age >= 20:
		_add_log("你已经成年，不应再向父母伸手要钱。")
		return

	var base_amount = 10 + randi_range(0, 15)
	var attr_val = char.attributes.get("cha", 10)
	var bonus = DiceSystem.attr_to_bonus(attr_val)
	var result = DiceSystem.roll_dice("2d6", bonus, 0)
	var amount = base_amount
	var tier_name = ""

	match result.tier:
		0:
			amount = base_amount * 2
			tier_name = "大成功"
		1:
			amount = base_amount
			tier_name = "成功"
		2:
			amount = int(base_amount / 2)
			tier_name = "部分成功"
		3:
			amount = 0
			tier_name = "失败"

	_add_log("向父母要钱——%s（尝试请求 %d 石）" % [tier_name, amount if amount > 0 else base_amount])

	if amount > 0:
		var ask_result = CharacterManager.ask_parents_for_money(char, amount)
		if ask_result.success:
			_add_log(ask_result.message)
		else:
			_add_log("要钱失败——" + ask_result.message)
	else:
		_add_log("被父母训斥了一顿，分文未得。")

	_mark_acted("ask_parents")

	_refresh_display()
	_age_gate_buttons()

func _refresh_display() -> void:
	var char = GameState.current_character
	if char.is_empty():
		return

	year_label.text = "公元前%d年" % abs(GameState.current_year)
	dynasty_label.text = DynastyManager.get_dynasty_name()
	location_label.text = "📍 %s" % GameState.current_location
	season_label.text = TimeManager.get_season_name()

	# ── 王背景（开局=周公教导，此后根据在位周王切换）──
	var bg_path := DynastyManager.get_king_background_path(GameState.current_year)
	var bg_tex := VisualConfig.load_texture(bg_path)
	if bg_tex and _city_bg_rect:
		_city_bg_rect.texture = bg_tex

	# ── 角色立绘 ──
	if _char_portrait and _char_portrait.texture == null:
		var portrait := VisualConfig.load_texture(VisualConfig.TEX_PORTRAIT_PLAYER)
		if portrait:
			_char_portrait.texture = portrait
		# 立绘加载后启动待机"呼吸"微动作（P3-2）
		if _char_portrait.texture != null:
			_start_portrait_idle()

	# 若无纹理则隐藏立绘区域，避免大段空白
	if _char_portrait:
		if _char_portrait.texture == null:
			_char_portrait.visible = false
			_char_portrait.custom_minimum_size = Vector2(0, 0)
		else:
			_char_portrait.visible = true

	char_name_label.text = "%s%s · %s氏" % [char.surname, char.get("name", ""), char.get("clan", "")]
	char_identity_label.text = "身份：%s（Lv%d）" % [CharacterManager.get_social_display(char), char.social_level]
	char_profession_label.text = "职业：%s" % char.get("profession", "")
	var pos_text = char.get("official_position", "")
	var id_parts = "身份：%s（Lv%d）" % [CharacterManager.get_social_display(char), char.social_level]
	var noble_disp = char.get("noble_title", "")
	if noble_disp == "":
		noble_disp = "未列侯"
	id_parts += " | 爵位：%s" % noble_disp
	if not pos_text.is_empty():
		id_parts += " | 官职：%s" % pos_text
	var fief_text = char.get("fief", "")
	if not fief_text.is_empty():
		id_parts += " | 封地：%s" % fief_text
	char_identity_label.text = id_parts

	var married_text = ""
	if CharacterManager.is_married(char):
		var s = char.relationships.spouse
		married_text = " | 配偶：%s%s" % [s.surname, s.name]
		var conc_count = GameState.family_data.get("concubines", []).size()
		var tf_count = GameState.family_data.get("tongfangs", []).size()
		var fr_count = GameState.family_data.get("furens", []).size()
		var yq_count = GameState.family_data.get("ying_qie", []).size()
		if conc_count > 0 or tf_count > 0 or fr_count > 0 or yq_count > 0:
			var details: Array[String] = []
			if fr_count > 0:
				details.append("夫人%d" % fr_count)
			if yq_count > 0:
				details.append("媵%d" % yq_count)
			if conc_count > 0:
				details.append("妾%d" % conc_count)
			if tf_count > 0:
				details.append("通房%d" % tf_count)
			married_text += "（" + ", ".join(details) + "）"
	var children = CharacterManager.get_character_children(char)
	var child_text = ""
	if not children.is_empty():
		var alive = []
		for c in children:
			if c.get("is_alive", true):
				var ca = GameState.current_year - c.birth_year
				alive.append("%s%s(%d岁)" % [c.surname, c.name, ca])
		if not alive.is_empty():
			child_text = " | 子女：" + ", ".join(alive)
	char_clan_label.text = "民族：%s | 姓：%s%s%s\n家声：%d · %s" % [
		char.ethnicity, char.surname, married_text, child_text,
		GameState.family_data.get("reputation", 0),
		_game_next_event_text()
	]

	var char_age = CharacterManager.get_character_age(char)
	char_age_label.text = "年龄：%d岁" % char_age
	char_stage_label.text = "阶段：%s" % TimeManager.get_life_stage_name(TimeManager.get_life_stage(char_age))

	var derived = char.get("derived", {})
	health_bar.value = derived.get("health", 100)
	reputation_bar.value = char.get("reputation", 0)
	power_bar.value = derived.get("power", 0)
	ambition_bar.value = derived.get("ambition", 0)
	wealth_label.text = "财富：%d 石 | 情报：%d" % [GameState.family_data.wealth, GameState.family_data.get("intel", 0)]
	# 家兵显示（多兵种）
	if _troops_label:
		var max_troops = char.get("max_troops", {})
		var has_troops = not max_troops.is_empty()
		if has_troops:
			_troops_label.visible = true
			var troops = char.get("household_troops", {})
			if troops is int:
				troops = {"步兵": troops, "车兵": 0, "王师": 0}
			var parts: Array[String] = []
			var total = 0
			for ttype in troops:
				var count = troops[ttype]
				total += count
				var limit = max_troops.get(ttype, 0)
				if limit > 0:
					parts.append("%s %d/%d" % [ttype, count, limit])
			if parts.is_empty():
				parts.append("无")
			_troops_label.text = "家兵：" + " | ".join(parts)
		else:
			_troops_label.visible = false
	if _recruit_troops_btn:
		_recruit_troops_btn.visible = not char.get("max_troops", {}).is_empty()
	if not _ambition_type.is_empty() and not _ambition_achieved:
		_update_ambition_display()

	var attrs = char.get("attributes", {})
	var attr_text = "属性："
	for attr in ["con", "int", "str", "cha", "vir", "luk"]:
		var val = attrs.get(attr, 10)
		var bonus = DiceSystem.attr_to_bonus(val)
		var sign = "+" if bonus >= 0 else ""
		attr_text += "\n  %s %d (%s%d)" % [CharacterManager.get_attr_display(attr), val, sign, bonus]
	attrs_label.text = attr_text

	var skills = char.get("skills", [])
	var skill_text = "技能："
	if skills.is_empty():
		skill_text += "\n  暂无"
	else:
		for s in skills:
			skill_text += "\n  · %s" % s
	skills_label.text = skill_text

	# ── 刷新家族列表 ──
	_build_family_content()

func _check_main_char_milestones(char: Dictionary) -> void:
	var age = CharacterManager.get_character_age(char)
	if not char.has("milestones_reached"):
		char["milestones_reached"] = []
	if age >= 6 and not char.milestones_reached.has(6):
		char.milestones_reached.append(6)
		CharacterManager.add_skill(char, "书数", 1)
		_add_log("🎓 你年满6岁，开始启蒙学习书数。")
		_age_gate_buttons()
	if age >= 12 and not char.milestones_reached.has(12):
		char.milestones_reached.append(12)
		CharacterManager.add_skill(char, "礼法", 1)
		_add_log("🎓 你年满12岁，开始学习礼法。")
		_age_gate_buttons()
	if age >= 16 and not char.milestones_reached.has(16):
		char.milestones_reached.append(16)
		CharacterManager.add_skill(char, "射御", 1)
		_add_log("🎓 你年满16岁，当行成人礼。")
		_show_coming_of_age_picker()

func _show_coming_of_age_picker() -> void:
	var popup = _make_popup("ComingOfAge", 210, 280)
	var vbox = _popup_vbox(popup)
	_add_popup_title(vbox, "🎊 成人礼——选择你的职业道路")
	var info = Label.new()
	info.text = "你已年满16岁，可行冠礼/笄礼，正式成丁。\n请选择今后的职业方向："
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)
	for prof in CharacterManager.SHI_PROFESSIONS:
		var btn = Button.new()
		btn.text = "%s —— %s" % [prof.name, prof.desc]
		btn.custom_minimum_size = Vector2(0, 34)
		btn.pressed.connect(_on_profession_chosen.bind(prof.id, popup))
		vbox.add_child(btn)
	add_child(popup)
	if _auto_mode:
		_auto_timer.stop()
	advance_btn.disabled = true
	rest_btn.disabled = true

func _on_profession_chosen(prof_id: String, popup: CanvasLayer) -> void:
	popup.queue_free()
	var char = GameState.current_character
	char.profession = prof_id
	_add_log("🎊 成人礼成！你选择了「%s」作为职业，正式踏上士族之路。" % prof_id)
	_age_gate_buttons()
	_check_ambition_progress()
	_refresh_display()
	advance_btn.disabled = false
	rest_btn.disabled = false
	_show_ambition_picker()
	if _auto_mode:
		_auto_timer.start()

func _on_toggle_auto() -> void:
	_auto_mode = not _auto_mode
	if _auto_mode:
		auto_btn.text = "⏸ 停止"
		_auto_timer.start()
		_add_log("⏩ 开启自动推进模式（每季自动）。")
	else:
		auto_btn.text = "⏩ 自动"
		_auto_timer.stop()
		_add_log("⏸ 关闭自动推进模式。")

func _on_auto_tick() -> void:
	if not _auto_mode:
		return
	var char = GameState.current_character
	if char.is_empty() or not char.get("is_alive", true):
		_on_toggle_auto()
		return
	# 成人礼选择中暂停自动
	if has_node("ComingOfAge"):
		return
	_on_advance_time()

func _show_childhood_fast_forward() -> void:
	# 使用 Window 弹窗（Godot 4 原生弹窗，确保不会被遮挡且始终响应点击）
	var popup = Window.new()
	popup.name = "ChildhoodSkip"
	popup.title = "童年时光"
	popup.size = Vector2(420, 260)
	popup.unresizable = true
	popup.always_on_top = true
	popup.transient = true
	popup.exclusive = true
	popup.close_requested.connect(func(): popup.queue_free())

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	popup.add_child(vbox)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	vbox.add_child(margin)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(content_vbox)

	var info = Label.new()
	info.text = "你刚刚降生在这个世界上。\n前方是16年的成长之路（64个季节）。\n你可以选择："
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_vbox.add_child(info)

	var fast_btn = Button.new()
	fast_btn.text = "快进至16岁（叙事摘要）"
	fast_btn.custom_minimum_size = Vector2(0, 44)
	fast_btn.pressed.connect(func():
		popup.queue_free()
		_fast_forward_to_16()
	)
	content_vbox.add_child(fast_btn)

	var slow_btn = Button.new()
	slow_btn.text = "逐季体验（64季完整成长）"
	slow_btn.custom_minimum_size = Vector2(0, 44)
	slow_btn.pressed.connect(func():
		popup.queue_free()
		_add_log("你选择逐季经历童年时光……")
		advance_btn.disabled = false
		rest_btn.disabled = false
		_refresh_display()
		_age_gate_buttons()
	)
	content_vbox.add_child(slow_btn)

	add_child(popup)
	popup.popup_centered()
	# 暂停其他操作直到选择完成
	advance_btn.disabled = true
	rest_btn.disabled = true
	if _auto_mode:
		_auto_timer.stop()

func _fast_forward_to_16() -> void:
	var char = GameState.current_character
	var old_birth = char.birth_year
	char.birth_year = GameState.current_year - 16
	char.age = 16
	# 童年里程碑技能
	if char.skills.is_empty():
		char.skills = []
	CharacterManager.add_skill(char, "书数", 1)
	CharacterManager.add_skill(char, "礼法", 1)
	char["milestones_reached"] = [6, 12, 16]
	char.derived = CharacterManager._calculate_derived(char)

	# 随机童年事件
	var events = [
		"4岁时，你与邻家孩童在田间追逐嬉戏，不慎跌入泥潭，被父亲一把提起。",
		"7岁那年，你偷尝了祭祀用的醴酒，醉倒在宗庙角落，被母亲狠狠责罚。",
		"9岁时，你随父亲入城，第一次见到镐京的繁华，立志要出人头地。",
		"11岁时，一场疫病席卷乡里，你在母亲的照料下安然度过，但目睹了生死无常。",
		"13岁时，你在乡学中与同窗辩论礼法，被夫子称赞「孺子可教」。",
		"14岁那年，你独自在山中迷路一夜，次日在猎户的指引下找到归途，从此不再惧怕黑暗。",
	]
	var picked = []
	var count = 2 + randi_range(0, 1)
	while picked.size() < count:
		var e = events[randi_range(0, events.size() - 1)]
		if e not in picked:
			picked.append(e)

	# 叙事弹窗
	var popup = _make_popup("ChildhoodSummary", 250, 260)
	var vbox = _popup_vbox(popup)
	_add_popup_title(vbox, "📜 童年纪事")
	var summary = "—— 16年光阴，转瞬即逝 ——\n\n"
	summary += "你出生在%s%s·%s氏家中，父亲%s%s为%s，母亲%s%s贤淑持家。\n\n" % [
		char.surname, char.name, char.clan,
		GameState.family_data.parents.father.surname,
		GameState.family_data.parents.father.name,
		GameState.family_data.parents.father.get("profession", "士"),
		GameState.family_data.parents.mother.surname,
		GameState.family_data.parents.mother.name,
	]
	summary += "6岁开蒙，你开始学习书数计数，辨认文字。\n"
	summary += "12岁学礼，你懂得了西周礼制的庄严与繁复。\n\n"
	for e in picked:
		summary += "▸ " + e + "\n"
	summary += "\n如今你年满16，该行成人礼，选择你的人生道路了。"
	var rtl = RichTextLabel.new()
	rtl.text = summary
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.scroll_active = false
	vbox.add_child(rtl)

	var ok_btn = Button.new()
	ok_btn.text = "▶ 行成人礼"
	ok_btn.custom_minimum_size = Vector2(0, 40)
	ok_btn.pressed.connect(func():
		popup.queue_free()
		_add_log("📜 童年岁月如白驹过隙……你已年满16岁。")
		_add_log("🎓 6岁开蒙，习得书数。")
		_add_log("🎓 12岁学礼，习得礼法。")
		for e in picked:
			_add_log("▸ " + e)
		advance_btn.disabled = false
		rest_btn.disabled = false
		_show_coming_of_age_picker()
		_refresh_display()
	)
	vbox.add_child(ok_btn)

	add_child(popup)

# ============================================================
# 治丧选择（父母去世）
# ============================================================
func _show_funeral_choice(funerals: Array) -> void:
	"""父母去世——多档治丧选择 + 父亲去世触发继承"""
	for funeral in funerals:
		var rel = funeral.get("relation", "")
		var rel_label = "父亲" if rel == "father" else "母亲"
		var name_str = funeral.get("name", "")
		var age = funeral.get("age", 0)
		_add_log("☠ %s%s去世，享年%d岁。" % [rel_label, name_str, age])

		# 父亲去世——先处理继承，再治丧
		if rel == "father":
			_handle_father_inheritance(funeral)

		# 治丧选择弹窗
		var popup := _make_popup("FuneralChoice", 270, 260)
		var vbox := _popup_vbox(popup)
		_add_popup_title(vbox, "⚰ %s%s的丧礼" % [rel_label, name_str])
		var w = GameState.family_data.wealth
		var info := Label.new()
		info.text = "%s%s享年%d岁，驾鹤西去。
家中现有 %d 石。你欲以何种规格治丧？" % [rel_label, name_str, age, w]
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(info)

		var grand_btn := Button.new()
		grand_btn.text = "🏛 大葬厚葬（40石，声望+20，德行或增）" + (" [钱财不足]" if w < 40 else "")
		grand_btn.custom_minimum_size = Vector2(0, 36)
		grand_btn.disabled = w < 40
		grand_btn.pressed.connect(_on_funeral_do.bind(funeral, "grand", popup))
		vbox.add_child(grand_btn)

		var mid_btn := Button.new()
		mid_btn.text = "🏺 家葬依礼（15石，声望+10）" + (" [钱财不足]" if w < 15 else "")
		mid_btn.custom_minimum_size = Vector2(0, 34)
		mid_btn.disabled = w < 15
		mid_btn.pressed.connect(_on_funeral_do.bind(funeral, "normal", popup))
		vbox.add_child(mid_btn)

		var simple_btn := Button.new()
		simple_btn.text = "🕯 薄棺简葬（5石，声望+3）" + (" [钱财不足]" if w < 5 else "")
		simple_btn.custom_minimum_size = Vector2(0, 34)
		simple_btn.disabled = w < 5
		simple_btn.pressed.connect(_on_funeral_do.bind(funeral, "simple", popup))
		vbox.add_child(simple_btn)

		var skip_btn := Button.new()
		skip_btn.text = "😕 草草了事（免费，声望-8）"
		skip_btn.custom_minimum_size = Vector2(0, 34)
		skip_btn.pressed.connect(_on_funeral_do.bind(funeral, "none", popup))
		vbox.add_child(skip_btn)

		add_child(popup)

func _handle_father_inheritance(funeral: Dictionary) -> void:
	"""父亲去世——继承爵位/职务/家族加成"""
	var char = GameState.current_character
	var parents = GameState.family_data.get("parents", {})
	var father = parents.get("father", {})

	# 继承父亲财富的一半
	var dad_wealth = father.get("wealth", 0)
	if dad_wealth > 0:
		var inherit_amount = int(dad_wealth / 2)
		CharacterManager.modify_wealth(inherit_amount)
		_add_log("💰 继承父亲遗产 %d 石（家产半数）。" % inherit_amount)

	# 继承父亲声望的1/3
	var dad_rep = father.get("reputation", 0)
	if dad_rep > 0:
		var rep_bonus = int(dad_rep / 3)
		CharacterManager.modify_reputation(char, rep_bonus)
		_add_log("🏛 继承父亲声望 %d 点（余荫庇佑）。" % rep_bonus)

	# 如果父亲社会等级高于自己，世袭承袭爵位/官职/封地（无衰减）
	var dad_level = father.get("social_level", 2)
	if dad_level > char.social_level:
		var heredit = CharacterManager._do_hereditary_succession(char, father)
		if heredit.get("success", false):
			_add_log("👑 继承父亲爵位——擢升为%s，承袭职务%s！" % [char.social_class, father.get("profession", "")])
			_add_log("🏛 族人推举你继任家主之位，宗族势力归心。")
	elif dad_level == char.social_level:
		_add_log("🏛 父亲去世，你正式执掌门户。族人以你为家主，宗族声望+5。")
		CharacterManager.modify_reputation(char, 5)

	# ── 分家：兄弟独立门户 ──
	var siblings = GameState.family_data.get("siblings", [])
	for sib in siblings:
		if not sib.get("is_alive", true) or sib.get("is_separated", false):
			continue
		if sib.get("gender", "male") != "male":
			continue
		var sib_age = GameState.current_year - sib.get("birth_year", GameState.current_year)
		if sib_age < 16:
			continue
		# 兄弟分家取家产15%
		var taken = int(GameState.family_data.wealth * 0.15)
		CharacterManager.modify_wealth(-taken)
		sib["is_separated"] = true
		_add_log("🏠 %s%s分家独立——带走 %d 石。" % [sib.surname, sib.get("name", ""), taken])
		# 记录支系
		GameState.family_data.branch_families.append({
			"founder_name": sib.get("name", ""),
			"founder_surname": sib.get("surname", ""),
			"wealth_taken": taken,
			"year": GameState.current_year,
			"is_di": true
		})

func _on_funeral_do(funeral: Dictionary, tier: String, popup: CanvasLayer) -> void:
	"""执行治丧——按档次扣除花费、增减声望"""
	popup.queue_free()
	var char = GameState.current_character
	var rel_label = "父亲" if funeral.get("relation") == "father" else "母亲"
	var name_str = funeral.get("name", "")
	match tier:
		"grand":
			CharacterManager.modify_wealth(-40)
			CharacterManager.modify_reputation(char, 20)
			_add_log("🏛 你为%s%s举办了隆重的厚葬——棺椁数重，随葬青铜礼器。乡邻无不赞叹你的孝心。声望+20。" % [rel_label, name_str])
			if randf() < 0.4:
				CharacterManager.modify_attribute(char, "vir", 1)
				_add_log("守孝期间你感悟良多——德行+1。")
		"normal":
			CharacterManager.modify_wealth(-15)
			CharacterManager.modify_reputation(char, 10)
			_add_log("🏺 你为%s%s依礼治丧——葬仪合乎规矩，族人点头称是。声望+10。" % [rel_label, name_str])
		"simple":
			CharacterManager.modify_wealth(-5)
			CharacterManager.modify_reputation(char, 3)
			_add_log("🕯 %s%s的丧礼从简，薄棺入土——虽不风光，也算入土为安。声望+3。" % [rel_label, name_str])
		"none":
			CharacterManager.modify_reputation(char, -8)
			_add_log("😕 %s%s的丧礼草草了事，裹席而葬……乡邻私下议论你不孝。声望-8。" % [rel_label, name_str])
	_refresh_display()

# ============================================================
# 负债检查
# ============================================================
func _check_debt_game_over() -> void:
	"""若财富持续为负超过2年（8季），家族破产，游戏结束"""
	if GameState.family_data.wealth < 0:
		_debt_seasons += 1
		if _debt_seasons >= 8:
			_add_log("☠☠ 家族负债累累，已过两年之期。债主盈门，家产尽没……")
			var char = GameState.current_character
			char.is_alive = false
			if _auto_mode:
				_on_toggle_auto()
			_refresh_display()
			_show_debt_bankruptcy()
			return
		elif _debt_seasons >= 4:
			_add_log("⚠ 家中已负债 %d 季，若持续两年恐有破产之虞！当前财富：%d 石。" % [_debt_seasons, GameState.family_data.wealth])
	else:
		_debt_seasons = 0

func _on_start_affair() -> void:
	"""玩家主动偷情——选择情人（固定列表，跨季保留）"""
	var char = GameState.current_character
	if not CharacterManager.is_married(char):
		_add_log("你尚未娶妻——何来偷情之说？")
		return
	var candidates = _generate_affair_candidates(char)
	if candidates.is_empty():
		_add_log("当下无可私会之人……")
		return
	var popup := _make_popup("StartAffair", 230, 60 + candidates.size() * 32)
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, "🌙 私会——选择对象")
	for c in candidates:
		var is_incest = CharacterManager.is_incestuous(char, {"surname": c.surname, "name": c.name})
		var label = "%s姓·%s — %s" % [c.surname, c.name, c.desc]
		if is_incest.get("is_incest", false):
			label += " ☠乱伦"
		var btn := Button.new()
		btn.text = label
		btn.custom_minimum_size = Vector2(0, 28)
		if is_incest.get("is_incest", false):
			btn.add_theme_color_override("font_color", Color.RED)
		btn.pressed.connect(_on_affair_target_chosen.bind(c, popup))
		vbox.add_child(btn)
	var cb := Button.new()
	cb.text = "取消"
	cb.pressed.connect(popup.queue_free)
	vbox.add_child(cb)
	add_child(popup)

func _generate_affair_candidates(char: Dictionary) -> Array:
	"""固定情人列表：无则生成 2-3 位初始情人（跨季保留），有则直接返回"""
	if not GameState.family_data.has("lovers"):
		GameState.family_data["lovers"] = []
	var lovers: Array = GameState.family_data["lovers"]
	if lovers.is_empty():
		var pool_size = 2 + randi_range(0, 1)
		var surnames = CharacterManager.EIGHT_SURNAMES.duplicate()
		surnames.erase(char.get("surname", ""))
		var male_names = ["虎", "龙", "昆", "昊", "晟", "青", "飞", "武"]
		var female_names = ["姜", "妃", "妍", "韵", "紫", "娜", "淑", "婉", "薇", "萍"]
		var npc_descs = ["邻家少妇", "采桑女", "贵族女子", "公卿家眷", "边邑戍卒之妻", "巫祝之女", "外乡旅人", "宫中侍女", "落魄士人"]
		for _i in range(pool_size):
			var s = surnames[randi_range(0, surnames.size() - 1)]
			var names_pool = female_names if char.get("gender", "male") == "male" else male_names
			var n = names_pool[randi_range(0, names_pool.size() - 1)]
			var d = npc_descs[randi_range(0, npc_descs.size() - 1)]
			lovers.append({"surname": s, "name": n, "desc": d, "intimacy": 0, "rumor": 0, "married": randi_range(0, 1) == 1})
	return lovers.duplicate()

func _on_affair_target_chosen(candidate: Dictionary, popup: CanvasLayer) -> void:
	"""选择情人对象 → 打开情人动作菜单"""
	popup.queue_free()
	var char = GameState.current_character
	var incest = CharacterManager.is_incestuous(char, {"surname": candidate.surname, "name": candidate.name})
	if incest.get("is_incest", false):
		_show_incest_blocked_popup(incest)
		return
	_show_lover_actions(candidate)

func _show_lover_actions(lover: Dictionary) -> void:
	"""情人动作菜单：私会/赠礼/温存（冷却按情人+动作区分）"""
	var lovers: Array = GameState.family_data.get("lovers", [])
	var li := -1
	for i in range(lovers.size()):
		if lovers[i].surname == lover.surname and lovers[i].name == lover.name:
			li = i
			break
	if li < 0:
		return
	var popup := _make_popup("LoverActions", 240, 210)
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, "🌙 %s姓·%s" % [lover.surname, lover.name])
	var info := Label.new()
	info.text = "%s · 亲密 %d · 风声 %d" % [lover.get("desc", ""), lover.get("intimacy", 0), lover.get("rumor", 0)]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)
	# 私会
	var meet_btn := Button.new()
	meet_btn.text = "🌿 私会（亲密+2 情报+1 风声+1）"
	meet_btn.custom_minimum_size = Vector2(0, 30)
	if not _can_act("lover_%d_meet" % li):
		meet_btn.disabled = true
		meet_btn.text += "  ✓本季已做"
	meet_btn.pressed.connect(func(): _do_lover_act(li, "meet", popup))
	vbox.add_child(meet_btn)
	# 赠礼
	var gift_btn := Button.new()
	gift_btn.text = "🎁 赠礼（亲密+3 花10石 风声+1）"
	gift_btn.custom_minimum_size = Vector2(0, 30)
	if not _can_act("lover_%d_gift" % li):
		gift_btn.disabled = true
		gift_btn.text += "  ✓本季已做"
	gift_btn.pressed.connect(func(): _do_lover_act(li, "gift", popup))
	vbox.add_child(gift_btn)
	# 温存
	var warm_btn := Button.new()
	warm_btn.text = "🔥 温存（亲密+3 情报+2 风声+1）"
	warm_btn.custom_minimum_size = Vector2(0, 30)
	if not _can_act("lover_%d_warm" % li):
		warm_btn.disabled = true
		warm_btn.text += "  ✓本季已做"
	warm_btn.pressed.connect(func(): _do_lover_act(li, "warm", popup))
	vbox.add_child(warm_btn)
	var close_btn := Button.new()
	close_btn.text = "离开"
	close_btn.custom_minimum_size = Vector2(0, 30)
	close_btn.pressed.connect(popup.queue_free)
	vbox.add_child(close_btn)
	add_child(popup)

func _do_lover_act(lover_index: int, act: String, popup: CanvasLayer) -> void:
	"""执行情人动作：亲密/风声/情报收益"""
	popup.queue_free()
	var cooldown_id := "lover_%d_%s" % [lover_index, act]
	if not _can_act(cooldown_id):
		_add_log("本季已做过此事，下季再来吧。")
		return
	var char = GameState.current_character
	var lovers: Array = GameState.family_data.get("lovers", [])
	if lover_index < 0 or lover_index >= lovers.size():
		return
	var lover: Dictionary = lovers[lover_index]
	var intimacy_gain := 0
	var intel_gain := 0
	var cost := 0
	var act_name := "私会"
	var icon := "🌿"
	match act:
		"meet":
			intimacy_gain = 2; intel_gain = 1; act_name = "私会"; icon = "🌿"
		"gift":
			cost = 10; intimacy_gain = 3; act_name = "赠礼"; icon = "🎁"
			if GameState.family_data.get("wealth", 0) < cost:
				_add_log("囊中羞涩——赠礼需 %d 石。" % cost)
				return
		"warm":
			intimacy_gain = 3; intel_gain = 2; act_name = "温存"; icon = "🔥"
		_:
			return
	lover["intimacy"] = lover.get("intimacy", 0) + intimacy_gain
	lover["rumor"] = lover.get("rumor", 0) + 1
	if cost > 0:
		CharacterManager.modify_wealth(-cost)
	if intel_gain > 0:
		GameState.family_data["intel"] = GameState.family_data.get("intel", 0) + intel_gain
	var extra := ""
	if intel_gain > 0:
		extra = "，情报+%d" % intel_gain
	elif cost > 0:
		extra = "，花 %d 石" % cost
	_add_log("%s 与%s姓·%s%s——亲密+%d，风声+1%s。" % [icon, lover.surname, lover.name, act_name, intimacy_gain, extra])
	# 高亲密情人为偷情带来真实收益（财富）
	if lover["intimacy"] >= 10:
		var grift = 3 + randi_range(0, 3)
		CharacterManager.modify_wealth(grift)
		_add_log("💰 %s姓·%s念及旧情，暗中接济你 %d 石。" % [lover.surname, lover.name, grift])
	_mark_acted(cooldown_id)
	_refresh_display()

func _check_lover_exposure() -> void:
	"""情人风声≥15 败露：丑闻+和睦降+报复/和离，败露后情缘断绝"""
	var lovers: Array = GameState.family_data.get("lovers", [])
	if lovers.is_empty():
		return
	var char = GameState.current_character
	for li in range(lovers.size() - 1, -1, -1):
		var lover: Dictionary = lovers[li]
		if lover.get("rumor", 0) < 15:
			continue
		CharacterManager.modify_scandal_level(1)
		GameState.household_data["harmony"] = max(0, GameState.household_data.get("harmony", 50) - 10)
		GameState.family_data.get("infidelity_log", []).append({
			"year": GameState.current_year,
			"person": "%s姓·%s" % [lover.get("surname", ""), lover.get("name", "")],
			"discovered": true, "penalty": -10, "action": "私情败露"
		})
		_add_log("💔 你与%s姓·%s的私情败露！家宅不宁——和睦-10，丑闻+1。" % [lover.get("surname", ""), lover.get("name", "")])
		var r := randi_range(0, 99)
		if r < 25 and CharacterManager.is_married(char):
			CharacterManager.modify_health(char, -5)
			_add_log("⚔ 情人之夫寻仇——你受了重伤，健康-5！")
		elif r < 50 and CharacterManager.is_married(char):
			var spouse = char.relationships.get("spouse", {})
			spouse["loyalty"] = max(0, spouse.get("loyalty", 50) - 30)
			_add_log("💢 正妻得知此事，心灰意冷——忠诚-30。")
		lovers.remove_at(li)
		_add_log("🌪 你与%s姓·%s情缘断绝。" % [lover.get("surname", ""), lover.get("name", "")])

func _show_incest_blocked_popup(result: Dictionary) -> void:
	"""乱伦阻止弹窗"""
	var relation = result.get("relation", "")
	var severity = result.get("severity", 1)
	var msg = result.get("message", "")
	var exiled = result.get("exiled", false)
	var demoted = result.get("demoted", false)
	_add_log("🚫 " + msg)
	var extra = ""
	if demoted:
		extra += "\n你被降级惩处。"
	if exiled:
		extra += "\n你被逐出宗族——流放异乡！"
	var popup := _make_popup("IncestBlocked", 240, 180)
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, "🚫 乱伦——宗族不容")
	var info := Label.new()
	info.text = msg + extra
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)
	var btn := Button.new()
	btn.text = "承受代价……"
	btn.custom_minimum_size = Vector2(0, 34)
	btn.pressed.connect(func(): popup.queue_free(); _refresh_display())
	vbox.add_child(btn)
	add_child(popup)

func _show_exile_event(result: Dictionary) -> void:
	"""流放事件弹窗"""
	var msg = result.get("message", "")
	var popup := _make_popup("ExileEvent", 240, 180)
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, "⚡ 流放之刑")
	var info := Label.new()
	info.text = msg + "\n财富减半，降级两级，逐出宗族……"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)
	var btn := Button.new()
	btn.text = "流徙异乡……"
	btn.custom_minimum_size = Vector2(0, 34)
	btn.pressed.connect(func(): popup.queue_free(); _refresh_display())
	vbox.add_child(btn)
	add_child(popup)

func _show_infidelity_popup(notices: Array) -> void:
	"""出轨发现弹窗——逐个处理"""
	for notice in notices:
		if not notice.get("discovered", false):
			continue  # 未发现的跳过，只暗中标记
		var person = notice.get("person", {})
		var person_type = notice.get("type", "")
		var person_name = notice.get("name", "")
		var label = ""
		match person_type:
			"wife": label = "正妻"
			"furen": label = "夫人"
			"ying_qie": label = "媵妾"
			"concubine": label = "妾室"
			"tongfang": label = "通房丫头"
			_: label = "妾室"
		_add_log("💔 你发现%s%s似有私情……" % [label, person_name])
		var popup := _make_popup("Infidelity", 240, 220)
		var vbox := _popup_vbox(popup)
		_add_popup_title(vbox, "💔 丑闻败露")
		var info := Label.new()
		info.text = "你发现%s%s与外人私通！\n此事若传开，家族声望将受重创。" % [label, person_name]
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(info)
		# 选项1: 休妻/逐妾（不可逆，先二次确认再执行）
		var divorce_cost = 10
		var btn1 := Button.new()
		btn1.text = "❌ 休弃（%d石，声望-5）" % divorce_cost
		btn1.custom_minimum_size = Vector2(0, 34)
		btn1.pressed.connect(func():
			popup.queue_free()
			_confirm("❌ 休弃%s%s" % [label, person_name],
				"此举不可挽回：%s将被逐出家门，\n家族声望 -5，花费 %d 石。\n你确定要这么做吗？" % [person_name, divorce_cost],
				true, func():
				CharacterManager.modify_wealth(-divorce_cost)
				CharacterManager.modify_reputation(GameState.current_character, -5)
				if person_type == "wife":
					GameState.current_character.relationships.spouse = {}
				elif person_type == "tongfang":
					var tfs = GameState.family_data.get("tongfangs", [])
					tfs.erase(person)
				elif person_type == "furen":
					var frs = GameState.family_data.get("furens", [])
					frs.erase(person)
				elif person_type == "ying_qie":
					var yqs = GameState.family_data.get("ying_qie", [])
					yqs.erase(person)
				else:
					var concs = GameState.family_data.get("concubines", [])
					concs.erase(person)
				_add_log("❌ 你休弃了%s%s——虽保全颜面，但家门蒙羞。" % [label, person_name])
				_refresh_display()
			)
		)
		vbox.add_child(btn1)
		# 选项2: 原谅
		var btn2 := Button.new()
		btn2.text = "🙏 原谅（声望-8）"
		btn2.custom_minimum_size = Vector2(0, 34)
		btn2.pressed.connect(func():
			popup.queue_free()
			CharacterManager.modify_reputation(GameState.current_character, -8)
			person["loyalty"] = min(100, person.get("loyalty", 50) + 15)
			CharacterManager.modify_scandal_level(1)
			GameState.family_data.infidelity_log.append({"year": GameState.current_year, "person": person_name, "discovered": true, "penalty": -8, "action": "原谅"})
			_add_log("🙏 你选择原谅%s%s——族人议论你软弱，但家中暂得安宁。" % [label, person_name])
			_refresh_display()
		)
		vbox.add_child(btn2)
		# 选项3: 暗中处理
		var btn3 := Button.new()
		btn3.text = "🔒 暗中处理（声望-3）"
		btn3.custom_minimum_size = Vector2(0, 34)
		btn3.pressed.connect(func():
			popup.queue_free()
			CharacterManager.modify_reputation(GameState.current_character, -3)
			person["loyalty"] = 85
			CharacterManager.modify_scandal_level(1)
			GameState.family_data.infidelity_log.append({"year": GameState.current_year, "person": person_name, "discovered": true, "penalty": -3, "action": "暗中处理"})
			_add_log("🔒 你选择秘而不宣——表面上波澜不惊，但丑闻已在暗处滋长。")
			_refresh_display()
		)
		vbox.add_child(btn3)
		add_child(popup)

func _show_debt_bankruptcy() -> void:
	"""负债破产——游戏结束画面"""
	disable_all_buttons()
	var char = GameState.current_character
	var popup := _make_popup("DebtBankruptcy", 250, 200)
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, "💸 家道中落")
	var label := Label.new()
	label.text = "你因长年负债，家产尽被债主所夺。

%s%s·%s氏的家业，
就此败落……
享年%d岁。" % [char.surname, char.get("name", ""), char.get("clan", ""), CharacterManager.get_character_age(char)]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(label)
	var heir = CharacterManager.get_heir(char)
	if not heir.is_empty():
		var heir_age = heir.get("current_age", 0)
		var heir_btn := Button.new()
		heir_btn.text = "👥 继承者：%s%s（%d岁）——延续家族血脉" % [heir.surname, heir.name, heir_age]
		heir_btn.custom_minimum_size = Vector2(0, 44)
		heir_btn.pressed.connect(func():
			popup.queue_free()
			_start_as_heir(char, heir)
		)
		vbox.add_child(heir_btn)
	else:
		var no_heir := Label.new()
		no_heir.text = "你未有继承人。
家族从此断绝……"
		no_heir.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(no_heir)
	var quit_btn := Button.new()
	quit_btn.text = "🏠 返回主菜单"
	quit_btn.custom_minimum_size = Vector2(0, 36)
	quit_btn.pressed.connect(func(): popup.queue_free(); get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	vbox.add_child(quit_btn)
	add_child(popup)

# ============================================================
# 1. 推进
# ============================================================
# ============================================================
# 好感度系统
# ============================================================

func _update_sibling_affection() -> void:
	"""每季好感度自然漂移"""
	var siblings = GameState.family_data.get("siblings", [])
	var allies = GameState.current_character.relationships.get("allies", [])
	for i in range(siblings.size()):
		var sib = siblings[i]
		if not sib.get("is_alive", true):
			continue
		if sib.get("is_separated", false):
			continue
		# 自然漂移 ±2
		var drift = -2 + randi_range(0, 4)
		# 结盟加成
		var is_ally = false
		for ally in allies:
			if ally.get("name", "") == sib.get("name", "") and ally.get("surname", "") == sib.get("surname", ""):
				is_ally = true
				break
		if is_ally:
			drift += 1
		CharacterManager.modify_sibling_affection(i, drift)

func _find_sibling_index(sibling_data: Dictionary) -> int:
	"""从兄弟数据找到在 family_data.siblings 中的索引"""
	var siblings = GameState.family_data.get("siblings", [])
	for i in range(siblings.size()):
		var sib = siblings[i]
		if sib.get("name", "") == sibling_data.get("name", "") and sib.get("surname", "") == sibling_data.get("surname", ""):
			return i
	return -1

func _on_gift_sibling(sibling_index: int) -> void:
	"""赠礼互动"""
	if sibling_index < 0:
		return
	var char = GameState.current_character
	var cost = 5
	if GameState.family_data.get("wealth", 0) < cost:
		_add_log("你囊中羞涩，无力赠礼。")
		return
	var siblings = GameState.family_data.get("siblings", [])
	var sib_name = siblings[sibling_index].get("name", "兄弟")
	var cha = char.attributes.get("cha", 10)
	var bonus = DiceSystem.attr_to_bonus(cha)
	var roll = DiceSystem.roll_dice("2d6", bonus, 0)
	var affection_gain = 5 + roll.tier * 3  # tier 0→14, tier 1→11, tier 2→8, tier 3→5
	CharacterManager.modify_sibling_affection(sibling_index, affection_gain)
	CharacterManager.modify_wealth(-cost)
	_add_log("🎁 向%s赠礼，好感+%d，花费%d石。" % [sib_name, affection_gain, cost])
	_mark_acted("gift_sibling_" + str(sibling_index))

func _on_break_ally_sibling(sibling_index: int) -> void:
	"""结盟决裂"""
	if sibling_index < 0:
		return
	CharacterManager.modify_sibling_affection(sibling_index, -20)
	var siblings = GameState.family_data.get("siblings", [])
	var sib_name = siblings[sibling_index].get("name", "兄弟")
	# 从盟友中移除
	var allies = GameState.current_character.relationships.get("allies", [])
	var to_remove = -1
	for j in range(allies.size()):
		if allies[j].get("name", "") == siblings[sibling_index].get("name", "") and allies[j].get("surname", "") == siblings[sibling_index].get("surname", ""):
			to_remove = j
			break
	if to_remove >= 0:
		allies.remove_at(to_remove)
		GameState.current_character.relationships["allies"] = allies
	_add_log("💔 与%s决裂，好感-20。" % sib_name)

# ============================================================
# 兄弟/姐妹事件弹窗
# ============================================================

func _show_sister_event_popup(event: Dictionary) -> void:
	"""姐妹事件弹窗"""
	var popup := _make_popup("SisterEvent", 250, 260)
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, "🌸 " + event.get("title", "姐妹事件"))
	var desc := Label.new()
	desc.text = event.get("desc", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)
	var event_type = event.get("type", "")
	# 选项按钮
	match event_type:
		"sister_talk":
			var btn0 := Button.new()
			btn0.text = "💬 倾听陪伴"
			btn0.custom_minimum_size = Vector2(0, 34)
			btn0.pressed.connect(func():
				popup.queue_free()
				var result = CharacterManager.resolve_sister_event(GameState.current_character, event, 0)
				_add_log("🌸 " + result.message)
				_refresh_display()
			)
			vbox.add_child(btn0)
			var btn1 := Button.new()
			btn1.text = "🚪 保持距离"
			btn1.custom_minimum_size = Vector2(0, 34)
			btn1.pressed.connect(func():
				popup.queue_free()
				var result = CharacterManager.resolve_sister_event(GameState.current_character, event, 1)
				_add_log("🌸 " + result.message)
				_refresh_display()
			)
			vbox.add_child(btn1)
		"sister_close":
			var btn0 := Button.new()
			btn0.text = "🕯 顺其自然"
			btn0.custom_minimum_size = Vector2(0, 34)
			btn0.pressed.connect(func():
				popup.queue_free()
				var result = CharacterManager.resolve_sister_event(GameState.current_character, event, 0)
				_add_log("🌸 " + result.message)
				_refresh_display()
			)
			vbox.add_child(btn0)
			var btn1 := Button.new()
			btn1.text = "🚶 借故离开"
			btn1.custom_minimum_size = Vector2(0, 34)
			btn1.pressed.connect(func():
				popup.queue_free()
				var result = CharacterManager.resolve_sister_event(GameState.current_character, event, 1)
				_add_log("🌸 " + result.message)
				_refresh_display()
			)
			vbox.add_child(btn1)
		"sister_incest":
			var btn0 := Button.new()
			btn0.text = "🔥 纵情（有风险）"
			btn0.custom_minimum_size = Vector2(0, 34)
			btn0.add_theme_color_override("font_color", Color.RED)
			btn0.pressed.connect(func():
				popup.queue_free()
				var result = CharacterManager.resolve_sister_event(GameState.current_character, event, 0)
				_add_log("🌸 " + result.message)
				_refresh_display()
			)
			vbox.add_child(btn0)
			var btn1 := Button.new()
			btn1.text = "✋ 克制自己"
			btn1.custom_minimum_size = Vector2(0, 34)
			btn1.pressed.connect(func():
				popup.queue_free()
				var result = CharacterManager.resolve_sister_event(GameState.current_character, event, 1)
				_add_log("🌸 " + result.message)
				_refresh_display()
			)
			vbox.add_child(btn1)
		"sister_letter":
			var btn0 := Button.new()
			btn0.text = "🔥 销毁证据"
			btn0.custom_minimum_size = Vector2(0, 34)
			btn0.pressed.connect(func():
				popup.queue_free()
				var result = CharacterManager.resolve_sister_event(GameState.current_character, event, 0)
				_add_log("🌸 " + result.message)
				_refresh_display()
			)
			vbox.add_child(btn0)
			var btn1 := Button.new()
			btn1.text = "💌 顺其自然"
			btn1.custom_minimum_size = Vector2(0, 34)
			btn1.pressed.connect(func():
				popup.queue_free()
				var result = CharacterManager.resolve_sister_event(GameState.current_character, event, 1)
				_add_log("🌸 " + result.message)
				_refresh_display()
			)
			vbox.add_child(btn1)
		"sister_oppose":
			var btn0 := Button.new()
			btn0.text = "🙇 低头认错"
			btn0.custom_minimum_size = Vector2(0, 34)
			btn0.pressed.connect(func():
				popup.queue_free()
				var result = CharacterManager.resolve_sister_event(GameState.current_character, event, 0)
				_add_log("🌸 " + result.message)
				_refresh_display()
			)
			vbox.add_child(btn0)
			var btn1 := Button.new()
			btn1.text = "💪 强辩到底"
			btn1.custom_minimum_size = Vector2(0, 34)
			btn1.add_theme_color_override("font_color", Color.RED)
			btn1.pressed.connect(func():
				popup.queue_free()
				var result = CharacterManager.resolve_sister_event(GameState.current_character, event, 1)
				_add_log("🌸 " + result.message)
				_refresh_display()
			)
			vbox.add_child(btn1)
	add_child(popup)

func _show_brother_event_popup(event: Dictionary) -> void:
	"""兄弟事件弹窗"""
	var is_neg = event.get("is_negative", false)
	var popup := _make_popup("BrotherEvent", 250, 220)
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, ("⚔ " if is_neg else "🤝 ") + event.get("title", "兄弟事件"))
	var desc := Label.new()
	desc.text = event.get("desc", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)
	var event_type = event.get("type", "")
	match event_type:
		"bro_heir_fight":
			var btn0 := Button.new()
			btn0.text = "💪 据理力争"
			btn0.custom_minimum_size = Vector2(0, 34)
			btn0.pressed.connect(func():
				popup.queue_free()
				var result = CharacterManager.resolve_brother_event(GameState.current_character, event, 0)
				_add_log("⚔ " + result.message)
				_refresh_display()
			)
			vbox.add_child(btn0)
			var btn1 := Button.new()
			btn1.text = "🤝 退让妥协"
			btn1.custom_minimum_size = Vector2(0, 34)
			btn1.pressed.connect(func():
				popup.queue_free()
				var result = CharacterManager.resolve_brother_event(GameState.current_character, event, 1)
				_add_log("⚔ " + result.message)
				_refresh_display()
			)
			vbox.add_child(btn1)
		_:
			# 单一结果事件
			var btn := Button.new()
			btn.text = "知道了"
			btn.custom_minimum_size = Vector2(0, 34)
			btn.pressed.connect(func():
				popup.queue_free()
				var result = CharacterManager.resolve_brother_event(GameState.current_character, event, 0)
				_add_log("⚔ " + result.message)
				_refresh_display()
			)
			vbox.add_child(btn)
	add_child(popup)

func _on_advance_time() -> void:
	var char = GameState.current_character
	TimeManager.advance_season()
	# 一次性初始化忠诚度（兼容旧存档）
	if not GameState.family_data.has("_loyalty_initialized"):
		GameState.family_data["_loyalty_initialized"] = true
		var spouse = char.relationships.get("spouse", {})
		if spouse and not spouse.is_empty() and not spouse.has("loyalty"):
			spouse["loyalty"] = 70 + randi_range(0, 20)
			spouse["last_affair_year"] = -9999
			if not spouse.has("is_pregnant"):
				spouse["is_pregnant"] = false
				spouse["pregnancy_remaining"] = 0
		var concs = GameState.family_data.get("concubines", [])
		for cn in concs:
			if not cn.has("loyalty"):
				cn["loyalty"] = 60 + randi_range(0, 20)
				cn["last_affair_year"] = -9999
			if not cn.has("is_pregnant"):
				cn["is_pregnant"] = false
				cn["pregnancy_remaining"] = 0
		for tf in GameState.family_data.get("tongfangs", []):
			if not tf.has("is_pregnant"):
				tf["is_pregnant"] = false
				tf["pregnancy_remaining"] = 0
		for fr in GameState.family_data.get("furens", []):
			if not fr.has("is_pregnant"):
				fr["is_pregnant"] = false
				fr["pregnancy_remaining"] = 0
		for yq in GameState.family_data.get("ying_qie", []):
			if not yq.has("is_pregnant"):
				yq["is_pregnant"] = false
				yq["pregnancy_remaining"] = 0
	# 兼容旧存档：为无 birth_year 的家族成员反算
	if not GameState.family_data.has("_birth_year_initialized"):
		GameState.family_data["_birth_year_initialized"] = true
		var cy = GameState.current_year
		if GameState.family_data.has("parents"):
			var p = GameState.family_data.parents
			if not p.father.has("birth_year"):
				p.father["birth_year"] = cy - p.father.get("age", cy)
			if not p.mother.has("birth_year"):
				p.mother["birth_year"] = cy - p.mother.get("age", cy)
		for sib in GameState.family_data.get("siblings", []):
			if not sib.has("birth_year"):
				sib["birth_year"] = cy - sib.get("age", 0)
		if CharacterManager.is_married(char):
			var sp = char.relationships.spouse
			if not sp.has("birth_year"):
				sp["birth_year"] = cy - sp.get("age", cy)
		for cn in GameState.family_data.get("concubines", []):
			if not cn.has("birth_year"):
				cn["birth_year"] = cy - cn.get("age", 0)
		for tf in GameState.family_data.get("tongfangs", []):
			if not tf.has("birth_year"):
				tf["birth_year"] = cy - tf.get("age", 0)
		for fr in GameState.family_data.get("furens", []):
			if not fr.has("birth_year"):
				fr["birth_year"] = cy - fr.get("age", 0)
		for yq in GameState.family_data.get("ying_qie", []):
			if not yq.has("birth_year"):
				yq["birth_year"] = cy - yq.get("age", 0)
	CharacterManager.update_character_age(char)

	# 旧档兼容：初始化兄弟姐妹好感度
	var relations = GameState.household_data.get("member_relations", {})
	var siblings = GameState.family_data.get("siblings", [])
	for i in range(siblings.size()):
		var key = "sibling_%d" % i
		if not relations.has(key):
			CharacterManager.init_sibling_affection(i)
	# 兼容：确保 member_relations 非空
	if GameState.household_data.get("member_relations", {}) == {}:
		GameState.household_data["member_relations"] = {}

	# 更新家庭和睦度
	var new_harmony = CharacterManager.calculate_household_harmony(char)
	GameState.household_data["harmony"] = new_harmony
	# 同步家庭私财（若未独立设置则跟随家族财富）
	if GameState.household_data.get("wealth", 0) == 0:
		GameState.household_data["wealth"] = GameState.family_data.get("wealth", 0)

	# 旧档兼容：通房丫头/夫人/媵妾字段
	if not GameState.family_data.has("tongfangs"):
		GameState.family_data["tongfangs"] = []
	if not GameState.family_data.has("furens"):
		GameState.family_data["furens"] = []
	if not GameState.family_data.has("ying_qie"):
		GameState.family_data["ying_qie"] = []
	# 旧档兼容：家兵字段
	if not char.has("household_troops"):
		char["household_troops"] = {"步兵": 0, "车兵": 0, "王师": 0}
		char["max_troops"] = CharacterManager.TROOP_LIMITS.get(char.get("social_level", 3), {})
	elif char["household_troops"] is int:
		# 旧整数格式→新字典格式
		var old_count = char["household_troops"]
		char["household_troops"] = {"步兵": old_count, "车兵": 0, "王师": 0}
		char["max_troops"] = CharacterManager.TROOP_LIMITS.get(char.get("social_level", 3), {})
	elif char.get("max_troops", 0) is int:
		# max_troops也是旧格式
		char["max_troops"] = CharacterManager.TROOP_LIMITS.get(char.get("social_level", 3), {})

	# 野心自然衰减（每季-1，最低0）—— 仅成年后生效
	var _adv_age = CharacterManager.get_character_age(char)
	if _adv_age >= 16:
		CharacterManager.modify_ambition(char, -1)

	# 负债检查——财富为负持续2年则游戏结束
	_check_debt_game_over()
	if not GameState.current_character.is_alive:
		return

	# 父母/兄弟姐妹/配偶/子女衰老
	var aging_result = CharacterManager.update_parents_aging()
	for notice in aging_result.get("notices", []):
		_add_log(notice)
	# 父母去世——弹出治丧选择
	var funerals: Array = aging_result.get("pending_funeral", [])
	if not funerals.is_empty():
		_show_funeral_choice(funerals)

		# 等级俸禄 —— 仅成年后获得
		if _adv_age >= 16:
			var income_info = CharacterManager.get_level_net_income(char.social_level)
			var net = income_info.net
			if net > 0:
				CharacterManager.modify_wealth(net)
			if income_info.expenses > 0:
				_add_log("本季俸禄 %d 石（扣除支出 %d 石，净得 %d 石）。" % [income_info.stipend, income_info.expenses, net])
			elif net > 0:
				_add_log("本季俸禄 %d 石。" % net)

		# 子女负担
		var children = CharacterManager.get_character_children(char)
		var living_minors = 0
		for child in children:
			if child.get("is_alive", true):
				var child_age = GameState.current_year - child.birth_year
				if child_age < 16:
					living_minors += 1
		if living_minors > 0:
			var burden = living_minors * 3
			CharacterManager.modify_wealth(-burden)
			_add_log("子女抚养——%d名未成年子女，花费 %d 石。" % [living_minors, burden])

	# 生育检查（孕期推进+分娩）—— 仅成年后检查
	if _adv_age >= 16:
		var pregnancy_notices = CharacterManager.process_pregnancies(char)
		for notice in pregnancy_notices:
			_add_log(notice)

	# ── 兄弟姐妹好感漂移 + 事件检测 ──
	_update_sibling_affection()
	if _adv_age >= 16:
		var sister_event = CharacterManager.check_sister_events(char)
		if not sister_event.is_empty():
			_show_sister_event_popup(sister_event)
		var brother_event = CharacterManager.check_brother_events(char)
		if not brother_event.is_empty():
			_show_brother_event_popup(brother_event)

	# 妻妾忠诚自然衰减（每季1-2，地板20；本季互动过不衰减）
	if _adv_age >= 16:
		for decay_row in CharacterManager._consorts_table(char):
			for di in range(decay_row.list.size()):
				var dm = decay_row.list[di]
				if dm.is_empty() or not dm.get("is_alive", true):
					continue
				if _is_intimate(decay_row.type, di):
					continue
				dm["loyalty"] = max(20, dm.get("loyalty", decay_row.default_loyalty) - randi_range(1, 2))
	# 情人风声败露检查
	_check_lover_exposure()

	# 配偶/妾室忠诚度检测 —— 仅成年后检查
	if _adv_age >= 16:
		var infidelity_notices = CharacterManager.check_spouse_fidelity(char)
		if not infidelity_notices.is_empty():
			_show_infidelity_popup(infidelity_notices)

		# 声望停滞检测（卿大夫及以上）
		if _adv_age >= 16:
			var stall_result = CharacterManager.check_reputation_stall(char)
			if not stall_result.message.is_empty():
				_add_log(stall_result.message)
			if stall_result.consequence == "demote":
				var target = char.social_level - 1
				CharacterManager.demote_character(char, target)
				_add_log("💔 被贬为%s……" % CharacterManager.SOCIAL_CLASSES[target].display)
				_refresh_display()
				return

	# 丑闻衰减（每4年减1级）
	if GameState.current_year % 4 == 0 and GameState.family_data.get("scandal_level", 0) > 0:
		var last_scandal = 9999
		for entry in GameState.family_data.get("infidelity_log", []):
			last_scandal = mini(last_scandal, entry.get("year", 9999))
		for entry in GameState.family_data.get("incest_log", []):
			last_scandal = mini(last_scandal, entry.get("year", 9999))
		if GameState.current_year - last_scandal >= 4:
			CharacterManager.modify_scandal_level(-1)

	# 子女成长里程碑
	# 子女教育进度推进
	var edu_notices = CharacterManager.process_child_education(char)
	for notice in edu_notices:
		_add_log(notice)
	var milestones = CharacterManager.check_child_milestones(char)
	for m in milestones:
		_add_log("🎓 " + m)

	# 主角童年里程碑（0-15岁）
	_check_main_char_milestones(char)

	# 死亡检查
	var age = _adv_age
	if age >= 30 and TimeManager.check_natural_death(age, char.attributes.get("con", 10)):
		_add_log("⚰ 你安详地离世了，享年%d岁。" % age)
		char.is_alive = false
		if _auto_mode:
			_on_toggle_auto()
		_refresh_display()
		# P3-3 死亡戏剧化转场：深红渐黑后弹结算菜单
		_play_death_transition(func(): _show_death_menu())
		return

	# 事件
	var event = EventManager.check_and_trigger()
	if not event.is_empty():
		_add_log("📜 触发事件：%s" % event.get("title", ""))
		var dialog = preload("res://scenes/event_dialog.tscn").instantiate()
		add_child(dialog)
	else:
		_add_log("暂无大事发生。")

	_met_king_this_season = false
	_attended_court_this_season = false
	_intimate_this_season = {}   # 新一季开始，清空亲密标记
	_age_gate_buttons()
	_refresh_display()

# ============================================================
# 2. 履职
# ============================================================
func _on_work() -> void:
	if not _can_act("work"):
		_add_log("本季已履行过职务，下季再来吧。")
		return
	var char = GameState.current_character
	var prof = char.get("profession", "")
	if prof.is_empty():
		_add_log("你还没有职业，无法履职。")
		return
	_show_work_options(prof)

func _show_work_options(prof: String) -> void:
	var popup = _make_popup("WorkOptions", 200, 200)
	var vbox = _popup_vbox(popup)
	_add_popup_title(vbox, "💼 履职 — %s" % prof)
	var options = [
		{"text": "🔥 勤勉（+50%收入，-5健康）", "mode": "hard"},
		{"text": "✅ 正常履职", "mode": "normal"},
		{"text": "😴 摸鱼（回复健康，收入减半）", "mode": "slack"},
	]
	for opt in options:
		var btn = Button.new()
		btn.text = opt.text
		btn.custom_minimum_size = Vector2(0, 36)
		btn.pressed.connect(_on_work_execute.bind(opt.mode, popup))
		vbox.add_child(btn)
	var cb = Button.new(); cb.text = "取消"; cb.pressed.connect(popup.queue_free); vbox.add_child(cb)
	add_child(popup)

func _on_work_execute(mode: String, popup: CanvasLayer) -> void:
	if popup: popup.queue_free()
	_last_work_mode = mode   # 记忆本次强度，供一键复用
	var char = GameState.current_character
	var prof = char.get("profession", "小吏")
	var attr_key = CharacterManager.get_profession_work_attr(prof)
	var attr_val = char.attributes.get(attr_key, 10)
	var bonus = DiceSystem.attr_to_bonus(attr_val)
	var base_income = CharacterManager.get_profession_income(prof)
	var income_mod = 1.0
	var health_delta = 0
	var mode_name = ""
	match mode:
		"hard":
			income_mod = 1.5; health_delta = -5; mode_name = "勤勉"
		"normal":
			mode_name = "正常"
		"slack":
			income_mod = 0.5; health_delta = 5; mode_name = "摸鱼"
	var result = DiceSystem.roll_dice("2d6", bonus, 0)
	match result.tier:
		0:
			var income0 := int(base_income * 2 * income_mod)
			CharacterManager.modify_wealth(income0)
			CharacterManager.modify_reputation(char, 5)
			_add_log("履职（%s·%s）——大成功！收入大幅提升。" % [prof, mode_name])
			_float_text(wealth_label, "+%d石" % income0, VisualConfig.GOLD)   # P1-2 Toast
			var cb = CharacterManager.get_profession_critical_bonus(prof)
			if not cb.is_empty():
				var sp = cb.trim_prefix("skill_").split(":")
				if sp.size() == 2:
					CharacterManager.add_skill(char, sp[0], int(sp[1]))
		1:
			var income1 := int(base_income * income_mod)
			CharacterManager.modify_wealth(income1)
			CharacterManager.modify_reputation(char, 2)
			_add_log("履职（%s·%s）——%s，获得收入。" % [prof, mode_name, result.tier_name])
			_float_text(wealth_label, "+%d石" % income1, VisualConfig.GOLD)   # P1-2 Toast
		2:
			var income2 := int(base_income * income_mod / 2)
			CharacterManager.modify_wealth(income2)
			_add_log("履职（%s·%s）——%s，收入微薄。" % [prof, mode_name, result.tier_name])
			_float_text(wealth_label, "+%d石" % income2, VisualConfig.GOLD)   # P1-2 Toast
		3:
			CharacterManager.modify_reputation(char, -2)
			_add_log("履职（%s·%s）——失败，工作出了差错。" % [prof, mode_name])
	if health_delta != 0:
		CharacterManager.modify_health(char, health_delta)
		_add_log("（%s：健康 %+d）" % [mode_name, health_delta])
		# P1-2 Toast：健康损耗用朱砂，回复用玉绿
		_float_text(health_bar, "健康 %+d" % health_delta,
			VisualConfig.VERMILLION if health_delta < 0 else VisualConfig.JADE)
	_mark_acted("work")
	_refresh_display()

# ============================================================
# 3. 修习
# ============================================================
func _on_study() -> void:
	if not _can_act("study"):
		_add_log("本季已修习过，下季再来吧。")
		return
	var char = GameState.current_character
	if CharacterManager.get_character_age(char) < 6:
		_add_log("你还太小，尚不能修习学问。待到6岁再来吧。")
		return
	_show_study_options()

func _show_study_options() -> void:
	var popup = _make_popup("StudyOptions", 200, 170)
	var vbox = _popup_vbox(popup)
	_add_popup_title(vbox, "📚 修习方式")
	var options = [
		{"text": "📖 自学（不花钱，正常效果）", "mode": "self"},
		{"text": "👨‍🏫 拜师（花20石，学习效果+1）", "mode": "master"},
	]
	for opt in options:
		var btn = Button.new()
		btn.text = opt.text
		btn.custom_minimum_size = Vector2(0, 36)
		btn.pressed.connect(_on_study_mode_chosen.bind(opt.mode, popup))
		vbox.add_child(btn)
	var cb = Button.new(); cb.text = "取消"; cb.pressed.connect(popup.queue_free); vbox.add_child(cb)
	add_child(popup)

var _study_bonus: int = 0
var _met_king_this_season: bool = false
var _attended_court_this_season: bool = false
var _ambition_plotted: bool = false
var _debt_seasons: int = 0

func _on_study_mode_chosen(mode: String, popup: CanvasLayer) -> void:
	popup.queue_free()
	_last_study_mode = mode   # 记忆本次修习方式，供一键复用
	if mode == "master":
		if GameState.family_data.wealth < 20:
			_add_log("拜师需要20石，你财力不足，改为自学。")
			_study_bonus = 0
		else:
			CharacterManager.modify_wealth(-20)
			_study_bonus = 1
			_add_log("花费20石拜师求学。")
	else:
		_study_bonus = 0
	_show_skill_picker()

func _show_skill_picker() -> void:
	var popup = _make_popup("SkillPicker", 200, 220)
	var vbox = _popup_vbox(popup)

	_add_popup_title(vbox, "📚 选择要修习的技能")
	var char = GameState.current_character
	for skill_full in CharacterManager.SKILLS:
		var lvl = 0
		for s in char.skills:
			if s.begins_with(skill_full + ":"):
				lvl = int(s.split(":")[1])
		var btn = Button.new()
		btn.text = "%s（Lv%d）%s" % [skill_full, lvl, "[已满]" if lvl >= 5 else ""]
		btn.custom_minimum_size = Vector2(0, 34)
		btn.disabled = lvl >= 5
		btn.pressed.connect(_on_skill_selected.bind(skill_full, popup))
		vbox.add_child(btn)

	var cb = Button.new(); cb.text = "取消"; cb.pressed.connect(popup.queue_free); vbox.add_child(cb)
	add_child(popup)

func _on_skill_selected(skill_name: String, popup: CanvasLayer) -> void:
	if popup: popup.queue_free()
	_last_study_skill = skill_name   # 记忆本次技能，供一键复用
	var char = GameState.current_character
	var attr_val = char.attributes.get("int", 10)
	var bonus = DiceSystem.attr_to_bonus(attr_val) + _study_bonus
	var result = DiceSystem.roll_dice("2d6", bonus, 0)
	var effects: Array = []

	match result.tier:
		0:
			var r = CharacterManager.study_skill(char, skill_name, 2 + _study_bonus)
			effects.append({"type": "skill", "name": skill_name, "value": 2 + _study_bonus})
			_add_log("修习%s——大成功！%s" % [skill_name, r.message])
		1:
			var r = CharacterManager.study_skill(char, skill_name, 1 + _study_bonus)
			effects.append({"type": "skill", "name": skill_name, "value": 1 + _study_bonus})
			_add_log("修习%s——成功。%s" % [skill_name, r.message])
		2:
			_add_log("修习%s——收效甚微，未能提升。" % skill_name)
		3:
			_add_log("修习%s——心不在焉，毫无收获。" % skill_name)

	# 修习提升对应属性
	var attr_key: String = CharacterManager.SKILL_TO_ATTR.get(skill_name, "")
	if not attr_key.is_empty():
		var attr_delta: int = effects.back().get("value", 1) if effects.size() > 0 else 1
		CharacterManager.modify_attribute(char, attr_key, attr_delta)
		var attr_display := CharacterManager.get_attr_display(attr_key)
		_add_log("修习%s——%s +%d" % [skill_name, attr_display, attr_delta])

	_mark_acted("study")
	_study_bonus = 0
	_refresh_display()

# ============================================================
# 3.5 一键履职/修习（P1-7 记忆上次强度）
# ============================================================
func _work_quick() -> void:
	if not _can_act("work"):
		_add_log("本季已履行过职务，下季再来吧。")
		return
	var char = GameState.current_character
	var prof = char.get("profession", "")
	if prof.is_empty():
		_add_log("你还没有职业，无法履职。")
		return
	if _last_work_mode.is_empty():
		_show_work_options(prof)      # 首次仍弹窗选择强度
	else:
		_on_work_execute(_last_work_mode, null)   # 之后一键复用上次强度

func _study_quick() -> void:
	if not _can_act("study"):
		_add_log("本季已修习过，下季再来吧。")
		return
	var char = GameState.current_character
	if CharacterManager.get_character_age(char) < 6:
		_add_log("你还太小，尚不能修习学问。待到6岁再来吧。")
		return
	if _last_study_mode.is_empty() or _last_study_skill.is_empty():
		_show_study_options()         # 首次仍弹窗选择方式+技能
	else:
		_apply_study_once(_last_study_mode, _last_study_skill)

func _apply_study_once(mode: String, skill_name: String) -> void:
	# 快速修习：直接按记忆的方式+技能执行（复用 _on_study_mode_chosen + _on_skill_selected 的结算逻辑）
	if mode == "master":
		if GameState.family_data.wealth < 20:
			_add_log("拜师需要20石，你财力不足，改为自学。")
			_study_bonus = 0
		else:
			CharacterManager.modify_wealth(-20)
			_study_bonus = 1
			_add_log("花费20石拜师求学。")
	else:
		_study_bonus = 0
	# 复用技能结算逻辑（与原 _on_skill_selected 一致）
	var c = GameState.current_character
	var attr_val = c.attributes.get("int", 10)
	var bonus = DiceSystem.attr_to_bonus(attr_val) + _study_bonus
	var result = DiceSystem.roll_dice("2d6", bonus, 0)
	var effects: Array = []
	match result.tier:
		0:
			var r0 = CharacterManager.study_skill(c, skill_name, 2 + _study_bonus)
			effects.append({"type": "skill", "name": skill_name, "value": 2 + _study_bonus})
			_add_log("修习%s——大成功！%s" % [skill_name, r0.message])
		1:
			var r1 = CharacterManager.study_skill(c, skill_name, 1 + _study_bonus)
			effects.append({"type": "skill", "name": skill_name, "value": 1 + _study_bonus})
			_add_log("修习%s——成功。%s" % [skill_name, r1.message])
		2:
			_add_log("修习%s——收效甚微，未能提升。" % skill_name)
		3:
			_add_log("修习%s——心不在焉，毫无收获。" % skill_name)
	var attr_key: String = CharacterManager.SKILL_TO_ATTR.get(skill_name, "")
	if not attr_key.is_empty() and effects.size() > 0:
		var attr_delta: int = effects.back().get("value", 1)
		CharacterManager.modify_attribute(c, attr_key, attr_delta)
		var attr_display := CharacterManager.get_attr_display(attr_key)
		_add_log("修习%s——%s +%d" % [skill_name, attr_display, attr_delta])
	_mark_acted("study")
	_study_bonus = 0
	_refresh_display()

# ============================================================
# 4. 交游
# ============================================================
func _on_socialize() -> void:
	if not _can_act("socialize"):
		_add_log("本季已社交过，下季再来吧。")
		return
	_show_socialize_options()

func _show_socialize_options() -> void:
	var popup = _make_popup("SocialOptions", 200, 200)
	var vbox = _popup_vbox(popup)
	_add_popup_title(vbox, "🤝 交游")
	var options = [
		{"text": "👥 结交同僚（声望+，安全稳妥）", "mode": "colleague"},
		{"text": "🎰 攀附上级（野心+，声望+，有风险）", "mode": "superior"},
		{"text": "💰 施恩下级（花钱20石，声望+）", "mode": "subordinate"},
	]
	for opt in options:
		var btn = Button.new()
		btn.text = opt.text
		btn.custom_minimum_size = Vector2(0, 36)
		btn.pressed.connect(_on_socialize_execute.bind(opt.mode, popup))
		vbox.add_child(btn)
	var cb = Button.new(); cb.text = "取消"; cb.pressed.connect(popup.queue_free); vbox.add_child(cb)
	add_child(popup)

func _on_socialize_execute(mode: String, popup: CanvasLayer) -> void:
	if popup: popup.queue_free()
	var char = GameState.current_character
	var loc = GameState.current_location
	var attr_val = char.attributes.get("cha", 10)
	var bonus = DiceSystem.attr_to_bonus(attr_val)
	if mode == "subordinate":
		if GameState.family_data.wealth < 20:
			_add_log("施恩下级需要至少20石，你财力不足。")
			return
		CharacterManager.modify_wealth(-20)
	var result = DiceSystem.roll_dice("2d6", bonus, 0)
	match mode:
		"colleague":
			match result.tier:
				0:
					CharacterManager.modify_reputation(char, 6)
					_add_log("交游（同僚）——大成功！结交了志同道合的朋友。声望+6")
				1:
					CharacterManager.modify_reputation(char, 3)
					_add_log("交游（同僚）——成功，人脉扩展。声望+3")
				2:
					CharacterManager.modify_reputation(char, 1)
					_add_log("交游（同僚）——平淡一叙。声望+1")
				3:
					_add_log("交游（同僚）——话不投机，不欢而散。")
		"superior":
			match result.tier:
				0:
					CharacterManager.modify_reputation(char, 10)
					CharacterManager.modify_ambition(char, 3)
					_add_log("交游（攀附）——大成功！获得了上级赏识！声望+10，野心+8")
				1:
					CharacterManager.modify_reputation(char, 5)
					CharacterManager.modify_ambition(char, 1)
					_add_log("交游（攀附）——成功，与上级建立了联系。声望+5，野心+3")
				2:
					_add_log("交游（攀附）——上级态度冷淡，未留下印象。")
				3:
					CharacterManager.modify_reputation(char, -3)
					CharacterManager.modify_ambition(char, -1)
					_add_log("交游（攀附）——冒犯了上级！声望-3，野心-2")
		"subordinate":
			match result.tier:
				0:
					CharacterManager.modify_reputation(char, 8)
					_add_log("交游（施恩）——大成功！慷慨解囊，赢得忠心的追随者！声望+8（花费20石）")
				1:
					CharacterManager.modify_reputation(char, 4)
					_add_log("交游（施恩）——成功，有人对你心怀感激。声望+4（花费20石）")
				2:
					CharacterManager.modify_reputation(char, 1)
					_add_log("交游（施恩）——施恩于人却未得回报。声望+1（花费20石）")
				3:
					CharacterManager.modify_reputation(char, -1)
					_add_log("交游（施恩）——被人当作冤大头嘲笑了！声望-1（花费20石）")
	_mark_acted("socialize")
	_refresh_display()

# ============================================================
# 纳妾对话框
# ============================================================

func _on_take_concubine() -> void:
	"""纳妾弹窗——选择姓氏、支付花费"""
	var char = GameState.current_character
	var info = CharacterManager.can_take_concubine(char)
	if not info.get("can", false):
		_add_log(info.get("reason", "无法纳妾。"))
		return
	var popup := _make_popup("TakeConcubine", 230, 250)
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, "\U0001f491 纳妾（同姓不婚）")
	var info_label := Label.new()
	info_label.text = "妾室名额：%d/%d\\n花费：%d 石 | 家中：%d 石" % [info.get("current", 0), info.max_count, info.cost, GameState.family_data.wealth]
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_label)
	var eligible = CharacterManager.get_eligible_surnames(char)
	var clans_map = {
		"姬": ["周", "鲁", "晋", "卫", "郑", "燕"], "姜": ["吕", "齐", "许", "申"],
		"姒": ["杞", "鄫", "褒"], "妫": ["陈", "田"], "嬴": ["秦", "赵", "徐"],
		"姞": ["南燕", "密"], "妘": ["郧", "邬"], "姚": ["姚"],
	}
	for surname in eligible:
		var clans = clans_map.get(surname, [surname])
		for clan in clans:
			var btn := Button.new()
			btn.text = "%s姓·%s氏" % [surname, clan]
			btn.custom_minimum_size = Vector2(0, 28)
			btn.pressed.connect(_on_concubine_confirm.bind(surname, clan, info.cost, popup))
			vbox.add_child(btn)
	var cb := Button.new()
	cb.text = "取消"
	cb.pressed.connect(popup.queue_free)
	vbox.add_child(cb)
	add_child(popup)

func _on_concubine_confirm(surname: String, clan: String, cost: int, popup: CanvasLayer) -> void:
	"""确认纳妾——掷骰检定"""
	popup.queue_free()
	var char = GameState.current_character
	var roll = DiceSystem.roll_dice("2d6", DiceSystem.attr_to_bonus(char.attributes.cha), 0)
	var tier = roll.get("tier", 2)
	var final_cost = cost
	var attr_bonus = 0
	match tier:
		0: final_cost = cost + 20; _add_log("对方族人拒之门外——花费增加。")
		1: final_cost = cost + 10; _add_log("对方犹豫再三——聘礼加价。")
		2: _add_log("纳妾成礼——")
		3: attr_bonus = 1; _add_log("相看两欢——")
		4: final_cost = int(cost / 2); attr_bonus = 2; _add_log("一见倾心——聘礼减半！")
	if final_cost < 0:
		final_cost = 0
	var result = CharacterManager.take_concubine(char, surname, clan, final_cost)
	if not result.get("success", false):
		_add_log(result.message)
		return
	_add_log(result.message)
	if attr_bonus > 0:
		var cn = result.concubine
		for _i in range(attr_bonus):
			var akeys = ["cha", "vir", "int"]
			var picked = akeys[randi_range(0, akeys.size() - 1)]
			if cn.has("attributes") and cn.attributes.has(picked):
				cn.attributes[picked] += 1
	# 纳新妾室→现有妾室忠诚度降低
	var concubines = GameState.family_data.get("concubines", [])
	for c in concubines:
		if c != result.get("concubine", {}):
			c["loyalty"] = max(20, c.get("loyalty", 80) - 10)
	_refresh_display()

# ============================================================
# 收通房丫头
# ============================================================

func _on_take_tongfang() -> void:
	"""收通房丫头弹窗——选择姓氏、支付花费"""
	var char = GameState.current_character
	var info = CharacterManager.can_take_tongfang(char)
	if not info.get("can", false):
		_add_log(info.get("reason", "无法收通房丫头。"))
		return
	var popup := _make_popup("TakeTongfang", 230, 250)
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, "🌸 收通房丫头")
	var info_label := Label.new()
	info_label.text = "通房名额：%d/%d\n花费：%d 石 | 家中：%d 石\n（地位低于妾室，花费较少）" % [info.get("current", 0), info.max_count, info.cost, GameState.family_data.wealth]
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_label)
	var eligible = CharacterManager.get_eligible_surnames(char)
	var clans_map = {
		"姬": ["周", "鲁", "晋", "卫", "郑", "燕"], "姜": ["吕", "齐", "许", "申"],
		"姒": ["杞", "鄫", "褒"], "妫": ["陈", "田"], "嬴": ["秦", "赵", "徐"],
		"姞": ["南燕", "密"], "妘": ["郧", "邬"], "姚": ["姚"],
	}
	for surname in eligible:
		var clans = clans_map.get(surname, [surname])
		for clan in clans:
			var btn := Button.new()
			btn.text = "%s姓·%s氏（约%d石）" % [surname, clan, info.cost]
			btn.custom_minimum_size = Vector2(0, 28)
			btn.pressed.connect(_on_tongfang_confirm.bind(surname, clan, info.cost, popup))
			vbox.add_child(btn)
	var cb := Button.new()
	cb.text = "取消"
	cb.pressed.connect(popup.queue_free)
	vbox.add_child(cb)
	add_child(popup)

func _on_tongfang_confirm(surname: String, clan: String, cost: int, popup: CanvasLayer) -> void:
	"""确认收通房——掷骰检定"""
	popup.queue_free()
	var char = GameState.current_character
	var roll = DiceSystem.roll_dice("2d6", DiceSystem.attr_to_bonus(char.attributes.cha), 0)
	var tier = roll.get("tier", 2)
	var final_cost = cost
	var attr_bonus = 0
	match tier:
		0: final_cost = cost + 10; _add_log("对方家人阻挠——多花了钱。")
		1: final_cost = cost + 5; _add_log("略有波折——加了些银钱。")
		2: _add_log("通房入室——")
		3: final_cost = int(cost / 2); attr_bonus = 1; _add_log("一拍即合——")
		4: final_cost = int(cost / 3); attr_bonus = 2; _add_log("两情相悦——花费大减！")
	if final_cost < 0:
		final_cost = 0
	var result = CharacterManager.take_tongfang(char, surname, clan, final_cost)
	if not result.get("success", false):
		_add_log(result.message)
		return
	_add_log(result.message)
	if attr_bonus > 0:
		var tf = result.tongfang
		for _i in range(attr_bonus):
			var akeys = ["cha", "vir", "int"]
			var picked = akeys[randi_range(0, akeys.size() - 1)]
			if tf.has("attributes") and tf.attributes.has(picked):
				tf.attributes[picked] += 1
	# 收新通房→现有通房忠诚度降低
	var tongfangs = GameState.family_data.get("tongfangs", [])
	for t in tongfangs:
		if t != result.get("tongfang", {}):
			t["loyalty"] = max(15, t.get("loyalty", 60) - 8)
	_refresh_display()

# ============================================================
# 册立夫人（天子专属）
# ============================================================

func _on_take_furen() -> void:
	"""天子册立夫人弹窗"""
	var char = GameState.current_character
	var info = CharacterManager.can_take_furen(char)
	if not info.get("can", false):
		_add_log(info.get("reason", "无法册立夫人。"))
		return
	var popup := _make_popup("TakeFuren", 230, 250)
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, "👑 册立夫人（天子后宫）")
	var info_label := Label.new()
	info_label.text = "夫人名额：%d/%d\n聘礼：%d 石 | 府库：%d 石\n（夫人位次王后，贵于嫔妾）" % [info.get("current", 0), info.max_count, info.cost, GameState.family_data.wealth]
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_label)
	var eligible = CharacterManager.get_eligible_surnames(char)
	var clans_map = {
		"姬": ["周", "鲁", "晋", "卫", "郑", "燕"], "姜": ["吕", "齐", "许", "申"],
		"姒": ["杞", "鄫", "褒"], "妫": ["陈", "田"], "嬴": ["秦", "赵", "徐"],
		"姞": ["南燕", "密"], "妘": ["郧", "邬"], "姚": ["姚"],
	}
	for surname in eligible:
		var clans = clans_map.get(surname, [surname])
		for clan in clans:
			var btn := Button.new()
			btn.text = "%s姓·%s氏（聘礼 %d 石）" % [surname, clan, info.cost]
			btn.custom_minimum_size = Vector2(0, 28)
			btn.pressed.connect(_on_furen_confirm.bind(surname, clan, info.cost, popup))
			vbox.add_child(btn)
	var cb := Button.new()
	cb.text = "取消"
	cb.pressed.connect(popup.queue_free)
	vbox.add_child(cb)
	add_child(popup)

func _on_furen_confirm(surname: String, clan: String, cost: int, popup: CanvasLayer) -> void:
	"""确认册立夫人——掷骰检定"""
	popup.queue_free()
	var char = GameState.current_character
	var roll = DiceSystem.roll_dice("2d6", DiceSystem.attr_to_bonus(char.attributes.cha), 0)
	var tier = roll.get("tier", 2)
	var final_cost = cost
	match tier:
		0: final_cost = cost + 50; _add_log("对方宗族索要厚礼——聘礼增加。")
		1: final_cost = cost + 20; _add_log("略有周折——多花了些钱。")
		2: _add_log("册立夫人——")
		3: final_cost = int(cost * 0.7); _add_log("天子威仪——聘礼减三成！")
		4: final_cost = int(cost * 0.5); _add_log("天下归心——聘礼减半！")
	if final_cost < 0:
		final_cost = 0
	var result = CharacterManager.take_furen(char, surname, clan, final_cost)
	if not result.get("success", false):
		_add_log(result.message)
		return
	_add_log(result.message)
	# 册立新夫人→现有妾室/通房/夫人忠诚度微降
	var furens = GameState.family_data.get("furens", [])
	for f in furens:
		if f != result.get("furen", {}):
			f["loyalty"] = max(30, f.get("loyalty", 85) - 5)
	_refresh_display()

# ============================================================
# 家庭面板
# ============================================================

func _show_household_panel() -> void:
	"""显示家庭面板——成员列表、和睦度、事件日志"""
	var char = GameState.current_character
	var members = CharacterManager.get_household_members(char)
	var harmony = CharacterManager.calculate_household_harmony(char)
	var hh_data = GameState.household_data
	var hh_wealth = hh_data.get("wealth", GameState.family_data.get("wealth", 0))
	if hh_wealth == 0: hh_wealth = GameState.family_data.get("wealth", 0)

	var popup := _make_popup("HouseholdPanel", 260, min(380, 120 + members.size() * 32))
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, "🏠 家庭（%s氏）" % char.get("clan", char.surname))

	# 和睦度
	var harmony_bar := ProgressBar.new()
	harmony_bar.min_value = 0; harmony_bar.max_value = 100
	harmony_bar.value = harmony
	harmony_bar.custom_minimum_size = Vector2(0, 16)
	var harmony_style := StyleBoxFlat.new()
	if harmony >= 70:
		harmony_style.bg_color = Color("2ecc71")
	elif harmony >= 40:
		harmony_style.bg_color = Color("f39c12")
	else:
		harmony_style.bg_color = Color("e74c3c")
	harmony_bar.add_theme_stylebox_override("fill", harmony_style)
	vbox.add_child(harmony_bar)
	var harmony_label := Label.new()
	harmony_label.text = "家庭和睦：%d/100  |  私财：%d 石" % [harmony, hh_wealth]
	vbox.add_child(harmony_label)

	var sep := HSeparator.new(); vbox.add_child(sep)

	# 成员列表
	for member in members:
		var is_preg = member.get("pregnant", false)
		var is_heir = member.get("heir", false)
		var edu = member.get("education", "")
		var extra = ""
		if is_preg: extra += " 🤰"
		if is_heir: extra += " 👑"
		if not edu.is_empty(): extra += " 📚"
		var member_label := Label.new()
		member_label.text = "  %s | %s·%s | %d岁 | %s%s" % [member.type, member.get("surname", ""), member.name, member.age, member.mood, extra]
		vbox.add_child(member_label)

	var sep2 := HSeparator.new(); vbox.add_child(sep2)

	# 近期家庭事件
	var events = GameState.household_data.get("events", [])
	var recent = events.slice(max(0, events.size() - 5), events.size())
	if recent.is_empty():
		var no_evt := Label.new()
		no_evt.text = "家中近来平安无事。"
		vbox.add_child(no_evt)
	else:
		var evt_title := Label.new()
		evt_title.text = "近期家事："
		vbox.add_child(evt_title)
		for evt in recent:
			var evt_label := Label.new()
			evt_label.text = "  · %s" % evt.get("description", "")
			evt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(evt_label)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(0, 32)
	close_btn.pressed.connect(popup.queue_free)
	vbox.add_child(close_btn)
	add_child(popup)

# ============================================================
# 5. 议亲（婚姻）
# ============================================================

func _spouse_btns_for_category(vbox: VBoxContainer, char: Dictionary) -> void:
	"""在社交分类中生成同房按钮列表（正妻/妾室/通房）"""
	# 正妻同房
	var wife = char.relationships.get("spouse", {})
	if not wife.is_empty():
		var w_preg = "（已孕）" if wife.get("is_pregnant", false) else ""
		# 冷却 ID 与家族面板"求子"共用，堵住绕过
		var w_btn := _make_action_btn("🏠 与妻同房%s" % w_preg, func():
			_do_try_for_baby("wife", 0)
		, "try_baby_wife")
		if wife.get("is_pregnant", false):
			w_btn.disabled = true
		vbox.add_child(w_btn)
	# 妾室同房
	var concubines = GameState.family_data.get("concubines", [])
	for i in range(concubines.size()):
		var cn = concubines[i]
		var cn_preg = "（已孕）" if cn.get("is_pregnant", false) else ""
		var ci = i
		var cn_btn := _make_action_btn("🛏 与妾%s同房%s" % [cn.get("name", "?"), cn_preg], func():
			_do_try_for_baby("concubine", ci)
		, "try_baby_concubine_" + str(ci))
		if cn.get("is_pregnant", false):
			cn_btn.disabled = true
		vbox.add_child(cn_btn)
	# 夫人同房（天子专属）
	var furens = GameState.family_data.get("furens", [])
	for i in range(furens.size()):
		var fr = furens[i]
		var fr_preg = "（已孕）" if fr.get("is_pregnant", false) else ""
		var fi = i
		var fr_btn := _make_action_btn("👑 与夫人%s同房%s" % [fr.get("name", "?"), fr_preg], func():
			_do_try_for_baby("furen", fi)
		, "try_baby_furen_" + str(fi))
		if fr.get("is_pregnant", false):
			fr_btn.disabled = true
		vbox.add_child(fr_btn)
	# 媵妾同房（诸侯专属）
	var ying_qie = GameState.family_data.get("ying_qie", [])
	for i in range(ying_qie.size()):
		var yq = ying_qie[i]
		var yq_preg = "（已孕）" if yq.get("is_pregnant", false) else ""
		var yi = i
		var yq_btn := _make_action_btn("🏰 与媵妾%s同房%s" % [yq.get("name", "?"), yq_preg], func():
			_do_try_for_baby("ying_qie", yi)
		, "try_baby_ying_qie_" + str(yi))
		if yq.get("is_pregnant", false):
			yq_btn.disabled = true
		vbox.add_child(yq_btn)
	# 通房同房（同样纳入冷却，堵住无限刷）
	var tongfangs = GameState.family_data.get("tongfangs", [])
	for i in range(tongfangs.size()):
		var tf = tongfangs[i]
		var tf_preg = "（已孕）" if tf.get("is_pregnant", false) else ""
		var ti = i
		var tf_btn := _make_action_btn("🌸 与通房%s同房%s" % [tf.get("name", "?"), tf_preg], func():
			_do_try_for_baby("tongfang", ti)
		, "try_baby_tongfang_" + str(ti))
		if tf.get("is_pregnant", false):
			tf_btn.disabled = true
		vbox.add_child(tf_btn)

func _on_marry() -> void:
	if not _can_act("marry"):
		_add_log("本季已议过亲，下季再来吧。")
		return
	var char = GameState.current_character
	if CharacterManager.is_married(char):
		_add_log("你已有配偶——%s%s·%s氏。" % [char.relationships.spouse.surname, char.relationships.spouse.name, char.relationships.spouse.clan])
		return

	# 先选择婚配方式
	var popup = _make_popup("MarryMode", 220, 160)
	var vbox = _popup_vbox(popup)
	_add_popup_title(vbox, "💍 议亲（同姓不婚）")

	var info := Label.new()
	info.text = "西周婚配，有父母之命与自行求娶两途。"
	vbox.add_child(info)

	var parent_btn := Button.new()
	parent_btn.text = "👴 父母之命（无需聘礼，父母包办）"
	parent_btn.custom_minimum_size = Vector2(0, 36)
	parent_btn.pressed.connect(_on_arranged_marriage.bind(popup))
	vbox.add_child(parent_btn)

	var self_btn := Button.new()
	self_btn.text = "💍 自己求娶（自选对象，需付聘礼）"
	self_btn.custom_minimum_size = Vector2(0, 36)
	self_btn.pressed.connect(_on_self_marry.bind(popup))
	vbox.add_child(self_btn)

	var cb = Button.new(); cb.text = "取消"; cb.pressed.connect(popup.queue_free); vbox.add_child(cb)
	add_child(popup)

func _on_self_marry(popup: CanvasLayer) -> void:
	popup.queue_free()
	var char = GameState.current_character
	var popup2 = _make_popup("MarryPicker", 210, 240)
	var vbox = _popup_vbox(popup2)
	_add_popup_title(vbox, "💍 自己求娶——选择对象")

	var eligible = CharacterManager.get_eligible_surnames(char)
	var clans_map = {
		"姬": ["周", "鲁", "晋", "卫", "郑", "燕"], "姜": ["吕", "齐", "许", "申"],
		"姒": ["杞", "鄫", "褒"], "妫": ["陈", "田"], "嬴": ["秦", "赵", "徐"],
		"姞": ["南燕", "密"], "妘": ["郧", "邬"], "姚": ["姚"],
	}

	for surname in eligible:
		var clans = clans_map.get(surname, [surname])
		for clan in clans:
			var dowry_cost = 50 + randi_range(0, 80)
			var btn = Button.new()
			btn.text = "%s姓·%s氏（聘礼约%d石）" % [surname, clan, dowry_cost]
			btn.custom_minimum_size = Vector2(0, 34)
			btn.pressed.connect(_on_marry_propose.bind(surname, clan, dowry_cost, popup2))
			vbox.add_child(btn)

	var cb = Button.new(); cb.text = "返回"; cb.pressed.connect(func(): popup2.queue_free(); _on_marry()); vbox.add_child(cb)
	add_child(popup2)

func _on_arranged_marriage(popup: CanvasLayer) -> void:
	popup.queue_free()
	var char = GameState.current_character
	_mark_acted("marry")

	# 检查父母是否在世
	if not GameState.family_data.has("parents"):
		_add_log("父母之命——可惜你的父母已不在世，只能靠自己了。")
		_on_marry()
		return
	var parents = GameState.family_data.parents
	var father_alive = parents.father.get("is_alive", false)
	var mother_alive = parents.mother.get("is_alive", false)
	if not father_alive and not mother_alive:
		_add_log("父母之命——可惜你的父母已不在世，只能靠自己了。")
		_on_marry()
		return

	# 父母为你挑选配偶
	var eligible = CharacterManager.get_eligible_surnames(char)
	if eligible.is_empty():
		_add_log("议亲失败——没有合适的对象。")
		return
	var chosen_surname: String = eligible[randi_range(0, eligible.size() - 1)]
	var clans_map = {
		"姬": ["周", "鲁", "晋", "卫", "郑", "燕"], "姜": ["吕", "齐", "许", "申"],
		"姒": ["杞", "鄫", "褒"], "妫": ["陈", "田"], "嬴": ["秦", "赵", "徐"],
		"姞": ["南燕", "密"], "妘": ["郧", "邬"], "姚": ["姚"],
	}
	var clan_list = clans_map.get(chosen_surname, [chosen_surname])
	var chosen_clan: String = clan_list[randi_range(0, clan_list.size() - 1)]

	# 父母操办，聘礼由父母出
	_add_log("👴 父母之命——父母为你定下了%s姓·%s氏的亲事，聘礼由家族承担。" % [chosen_surname, chosen_clan])

	# 直接结婚
	var marriage = CharacterManager.propose_marriage_parents(char, chosen_surname, chosen_clan)
	if not marriage.success:
		_add_log("议亲失败——" + marriage.message)
		return

	_add_log("💒 " + marriage.message)
	_do_family_separation()
	_refresh_display()

func _do_family_separation() -> void:
	var char = GameState.current_character
	if char.get("_separated", false):
		return
	char["_separated"] = true

	var separation_gift := 20 + randi_range(0, 30)
	CharacterManager.modify_wealth(separation_gift)
	_add_log("🏠 婚后分家——你从父母家中独立门户。家族赠予 %d 石作为安家费。" % separation_gift)

func _on_marry_propose(surname: String, clan: String, dowry: int, popup: CanvasLayer) -> void:
	popup.queue_free()
	var char = GameState.current_character
	_mark_acted("marry")
	var attr_val = char.attributes.get("cha", 10)
	var bonus = DiceSystem.attr_to_bonus(attr_val)
	var result = DiceSystem.roll_dice("2d6", bonus, 0)

	match result.tier:
		0:
			# 大成功——对方很满意，聘礼减半
			var reduced: int = max(dowry / 2, 20)
			_add_log("议亲——%s姓·%s氏对你非常满意！聘礼从%d石减至%d石。" % [surname, clan, dowry, reduced])
			var marriage0 = CharacterManager.propose_marriage(char, surname, clan, reduced)
			if not marriage0.success:
				_add_log("议亲失败——" + marriage0.message)
				return
			_add_log("💒 " + marriage0.message)
			_do_family_separation()
			_refresh_display()
		1:
			# 成功——正常提亲
			var marriage1 = CharacterManager.propose_marriage(char, surname, clan, dowry)
			if not marriage1.success:
				_add_log("议亲失败——" + marriage1.message)
				return
			_add_log("💒 " + marriage1.message)
			_do_family_separation()
			_refresh_display()
		2:
			# 部分成功——对方犹豫，需要加20石聘礼
			var extra: int = dowry + 20
			_add_log("议亲——%s姓·%s氏有些犹豫，要求增加聘礼至%d石……" % [surname, clan, extra])
			if GameState.family_data.wealth < extra:
				_add_log("议亲失败——聘礼不足。需要 %d 石，你只有 %d 石。" % [extra, GameState.family_data.wealth])
				return
			var marriage2 = CharacterManager.propose_marriage(char, surname, clan, extra)
			if not marriage2.success:
				_add_log("议亲失败——" + marriage2.message)
				return
			_add_log("💒 " + marriage2.message)
			_do_family_separation()
			_refresh_display()
		3:
			# 失败——对方拒绝
			CharacterManager.modify_reputation(char, -1)
			_add_log("议亲失败——%s姓·%s氏婉拒了你的提亲。声誉-1" % [surname, clan])

# ============================================================
# 6. 祭祀
# ============================================================
func _on_ritual() -> void:
	if not _can_act("ritual"):
		_add_log("本季已祭祀过，下季再来吧。")
		return
	_show_ritual_options()

func _show_ritual_options() -> void:
	var popup = _make_popup("RitualOptions", 200, 200)
	var vbox = _popup_vbox(popup)
	_add_popup_title(vbox, "🏛 祭祀先祖")
	var w = GameState.family_data.wealth
	var options = [
		{"text": "👑 大祭（30石，声望+++，野心+）", "cost": 30, "mode": "grand", "disabled": w < 30},
		{"text": "🏺 家祭（10石，声望+）", "cost": 10, "mode": "normal", "disabled": w < 10},
		{"text": "🙏 心祭（不花钱，心诚则灵）", "cost": 0, "mode": "simple", "disabled": false},
	]
	for opt in options:
		var btn = Button.new()
		btn.text = opt.text + (" [财力不足]" if opt.disabled else "")
		btn.custom_minimum_size = Vector2(0, 36)
		btn.disabled = opt.disabled
		btn.pressed.connect(_on_ritual_execute.bind(opt.cost, opt.mode, popup))
		vbox.add_child(btn)
	var cb = Button.new(); cb.text = "取消"; cb.pressed.connect(popup.queue_free); vbox.add_child(cb)
	add_child(popup)

func _on_ritual_execute(cost: int, mode: String, popup: CanvasLayer) -> void:
	if popup: popup.queue_free()
	if cost > 0:
		CharacterManager.modify_wealth(-cost)
	var char = GameState.current_character
	var attr_val = char.attributes.get("vir", 10)
	var bonus = DiceSystem.attr_to_bonus(attr_val)
	var result = DiceSystem.roll_dice("2d6", bonus, 0)
	match mode:
		"grand":
			match result.tier:
				0:
					CharacterManager.modify_reputation(char, 15)
					CharacterManager.modify_ambition(char, 3)
					_add_log("大祭——大成功！先祖显灵，钟鸣鼎食，福泽深厚！声望+15，野心+8（花费30石）")
				1:
					CharacterManager.modify_reputation(char, 8)
					CharacterManager.modify_ambition(char, 1)
					_add_log("大祭——礼成，先祖欣慰。声望+8，野心+3（花费30石）")
				2:
					CharacterManager.modify_reputation(char, 3)
					_add_log("大祭——排场虽大，心意不足。声望+3（花费30石）")
				3:
					CharacterManager.modify_reputation(char, -2)
					_add_log("大祭——仪式出了大纰漏，沦为笑柄！声望-2（花费30石）")
		"normal":
			match result.tier:
				0:
					CharacterManager.modify_reputation(char, 8)
					CharacterManager.modify_ambition(char, 1)
					_add_log("家祭——大成功！心诚则灵，先祖赐福。声望+8（花费10石）")
				1:
					CharacterManager.modify_reputation(char, 5)
					_add_log("家祭——礼成，聊表孝心。声望+5（花费10石）")
				2:
					CharacterManager.modify_reputation(char, 2)
					_add_log("家祭——中规中矩。声望+2（花费10石）")
				3:
					_add_log("家祭——祭品不洁，先祖不悦。（花费10石）")
		"simple":
			match result.tier:
				0:
					CharacterManager.modify_reputation(char, 5)
					_add_log("心祭——大成功！精诚所至，金石为开。先祖感受到了你的赤诚。声望+5")
				1:
					CharacterManager.modify_reputation(char, 2)
					_add_log("心祭——心到神知。声望+2")
				2:
					_add_log("心祭——心意到了，但效果平平。")
				3:
					CharacterManager.modify_reputation(char, -1)
					_add_log("心祭——心不在焉，先祖不悦。声望-1")
	_mark_acted("ritual")
	_refresh_display()

# ============================================================
# 7. 出行
# ============================================================
func _on_travel() -> void:
	if not _can_act("travel"):
		_add_log("本季已出行过，下季再来吧。")
		return
	_show_city_picker()

func _show_city_picker() -> void:
	var cities = DynastyManager.get_cities()
	if cities.is_empty():
		return

	var popup = _make_popup("CityPicker", 230, 80 + cities.size() * 38)
	var vbox = _popup_vbox(popup)
	_add_popup_title(vbox, "🗺 选择目的地（当前：%s）" % GameState.current_location)

	for city in cities:
		var btn = Button.new()
		btn.text = "%s — %s" % [city.get("name", ""), city.get("desc", "")]
		btn.custom_minimum_size = Vector2(0, 34)
		btn.pressed.connect(_on_city_selected.bind(city, popup))
		vbox.add_child(btn)

	var cb = Button.new(); cb.text = "取消"; cb.pressed.connect(popup.queue_free); vbox.add_child(cb)
	add_child(popup)

func _on_city_selected(city: Dictionary, popup: CanvasLayer) -> void:
	popup.queue_free()
	_mark_acted("travel")
	var city_name = city.get("name", "")
	if city_name == GameState.current_location:
		_add_log("你已经在这里了。")
		return

	var char = GameState.current_character
	var season_mod = TimeManager.get_season_movement_modifier()
	var attr_val = char.attributes.get("luk", 10)
	var bonus = DiceSystem.attr_to_bonus(attr_val)
	var luck_mod = int((1.5 - season_mod) * 3)
	var result = DiceSystem.roll_dice("2d6", bonus, luck_mod)
	var effects: Array = []

	match result.tier:
		0: _add_log("出行%s——旅途非常顺利！" % city_name)
		1: _add_log("出行%s——平安抵达。%s" % [city_name, city.get("desc", "")])
		2:
			CharacterManager.modify_health(char, -3)
			effects.append({"type": "health", "value": -3})
			_add_log("出行%s——路途有些波折，受了点轻伤。" % city_name)
		3:
			CharacterManager.modify_health(char, -8)
			CharacterManager.modify_wealth(-5)
			effects.append_array([{"type": "health", "value": -8}, {"type": "wealth", "value": -5}])
			_add_log("出行%s——遭遇不测！损失惨重……" % city_name)

	GameState.change_location(city_name)
	_refresh_display()
# ============================================================
# 8. 田猎
# ============================================================
func _on_hunt() -> void:
	if not _can_act("hunt"):
		_add_log("本季已田猎过，下季再来吧。")
		return

	var char = GameState.current_character
	var attr_val = char.attributes.get("str", 10)
	var bonus = DiceSystem.attr_to_bonus(attr_val)
	var season = TimeManager.current_season
	# 秋季狩猎最佳
	var season_bonus = 1 if season == TimeManager.Season.AUTUMN else (0 if season == TimeManager.Season.WINTER else 0)
	var result = DiceSystem.roll_dice("2d6", bonus, season_bonus)
	var effects: Array = []

	match result.tier:
		0:
			var income = 30 + randi_range(0, 40)
			CharacterManager.modify_wealth(income)
			CharacterManager.modify_reputation(char, 3)
			effects.append_array([{"type": "wealth", "value": income}, {"type": "reputation", "value": 3}])
			_add_log("田猎——大丰收！捕获珍禽异兽，获利 %d 石！" % income)
		1:
			var income = 15 + randi_range(0, 20)
			CharacterManager.modify_wealth(income)
			effects.append({"type": "wealth", "value": income})
			_add_log("田猎——有所收获，获得 %d 石。" % income)
		2:
			var income = 5 + randi_range(0, 10)
			CharacterManager.modify_wealth(income)
			effects.append({"type": "wealth", "value": income})
			_add_log("田猎——收获不多，聊胜于无。")
		3:
			CharacterManager.modify_health(char, -5)
			effects.append({"type": "health", "value": -5})
			_add_log("田猎——不慎受伤，空手而归……")

	_mark_acted("hunt")
	# 田猎可能触发额外遭遇
	if result.tier == 0 and randf() < 0.2:
		_add_log("田猎途中遭遇了一头罕见的白鹿——这是吉兆！")
		CharacterManager.modify_reputation(char, 5)

	_refresh_display()

# ============================================================
# 9. 市集
# ============================================================
func _on_market() -> void:
	if not _can_act("market"):
		_add_log("本季已逛过市集，下季再来吧。")
		return
	_show_market()

func _show_market() -> void:
	var popup = _make_popup("MarketPopup", 200, 280)
	var vbox = _popup_vbox(popup)
	_add_popup_title(vbox, "📦 镐京市集（财富：%d 石）" % GameState.family_data.wealth)

	var goods = [
		{"name": "青铜礼器", "cost": 60, "desc": "提升声望的祭祀用品", "effect": "rep"},
		{"name": "兵甲一套", "cost": 40, "desc": "上好的兵器与甲胄", "effect": "str_temp"},
		{"name": "竹简典籍", "cost": 30, "desc": "记载先贤智慧的竹简", "effect": "int_temp"},
		{"name": "药材补品", "cost": 25, "desc": "恢复健康的珍贵药材", "effect": "heal"},
		{"name": "精美玉器", "cost": 50, "desc": "可作为聘礼或送礼之用", "effect": "gift"},
		{"name": "盐铁杂货", "cost": 15, "desc": "日常必需物资", "effect": "wealth_small"},
	]
	for g in goods:
		var btn = Button.new()
		btn.text = "%s — %d 石 | %s" % [g.name, g.cost, g.desc]
		btn.custom_minimum_size = Vector2(0, 34)
		btn.pressed.connect(_on_market_buy.bind(g, popup))
		vbox.add_child(btn)

	var cb = Button.new(); cb.text = "离开市集"; cb.pressed.connect(popup.queue_free); vbox.add_child(cb)
	add_child(popup)

func _on_market_buy(goods: Dictionary, popup: CanvasLayer) -> void:
	popup.queue_free()
	_mark_acted("market")
	var char = GameState.current_character
	var cost = goods.cost
	if GameState.family_data.wealth < cost:
		_add_log("市集——钱财不足，买不起%s。" % goods.name)
		return

	CharacterManager.modify_wealth(-cost)
	_add_log("市集——花费 %d 石购买了%s。" % [cost, goods.name])

	var effects: Array = [{"type": "wealth", "value": -cost}]
	match goods.effect:
		"rep":
			CharacterManager.modify_reputation(char, 8)
			effects.append({"type": "reputation", "value": 8})
		"str_temp":
			_add_log("装备了兵甲，下次战斗更有把握了！")
		"int_temp":
			_add_log("研读典籍，智慧有所增长！")
		"heal":
			CharacterManager.modify_health(char, 20)
			effects.append({"type": "health", "value": 20})
		"gift":
			CharacterManager.modify_reputation(char, 4)
			effects.append({"type": "reputation", "value": 4})
		"wealth_small":
			_add_log("盐铁杂货可在日后转卖。")

	_refresh_display()

# ============================================================
# 10. 教子
# ============================================================
func _on_teach_child() -> void:
	var char = GameState.current_character
	var children = CharacterManager.get_character_children(char)
	var alive = []
	for c in children:
		if c.get("is_alive", true):
			alive.append(c)

	if alive.is_empty():
		_add_log("你没有可以教育的子女。")
		return

	if not _can_act("teach"):
		_add_log("本季已教导过子女，下季再来吧。")
		return

	_show_teach_picker(alive)

func _show_teach_picker(children: Array) -> void:
	var popup = _make_popup("TeachPicker", 220, 100 + children.size() * 80)
	var vbox = _popup_vbox(popup)
	_add_popup_title(vbox, "👨‍🏫 选择要教导的子女")

	var subjects = ["礼法", "射御", "书数", "乐", "兵法", "游说"]
	for i in range(children.size()):
		var child = children[i]
		var age = GameState.current_year - child.birth_year
		var child_skills = child.get("skills", [])
		var skill_texts = []
		for sk in child_skills:
			skill_texts.append(sk)
		var skills_str = ", ".join(skill_texts) if not skill_texts.is_empty() else "无"

		var child_box = VBoxContainer.new()
		child_box.add_theme_constant_override("separation", 4)
		var info = Label.new()
		info.text = "%s%s（%d岁）——已有技能：%s" % [child.surname, child.name, age, skills_str]
		child_box.add_child(info)

		var btn_box = HBoxContainer.new()
		btn_box.add_theme_constant_override("separation", 4)
		for subj in subjects:
			var btn = Button.new()
			btn.text = subj
			btn.custom_minimum_size = Vector2(55, 28)
			var ci = i
			btn.pressed.connect(_on_teach_subject.bind(ci, subj, popup))
			btn_box.add_child(btn)
		child_box.add_child(btn_box)
		vbox.add_child(child_box)

	var cb = Button.new(); cb.text = "取消"; cb.pressed.connect(popup.queue_free)
	vbox.add_child(cb)
	add_child(popup)

func _on_teach_subject(child_index: int, subject: String, popup: CanvasLayer) -> void:
	if popup: popup.queue_free()
	var char = GameState.current_character
	var result = CharacterManager.educate_child(char, child_index, subject)
	_mark_acted("teach")
	_add_log("教子——" + result.message)
	_refresh_display()

# ============================================================
# 11. 休憩（旧10）
# ============================================================
func _on_rest() -> void:
	if not _can_act("rest"):
		_add_log("本季已休憩过，下季再来吧。")
		return

	var char = GameState.current_character
	var attr_val = char.attributes.get("con", 10)
	var bonus = DiceSystem.attr_to_bonus(attr_val)
	var result = DiceSystem.roll_dice("2d6", bonus, 0)
	var effects: Array = []
	var heal = [30, 18, 8, 3][result.tier]
	CharacterManager.modify_health(char, heal)
	effects.append({"type": "health", "value": heal})
	if result.tier == 0:
		CharacterManager.modify_ambition(char, 1)
		effects.append({"type": "ambition", "value": 3})

	_mark_acted("rest")
	_add_log("休憩——%s，恢复了 %d 健康。" % [result.tier_name, heal])
	_refresh_display()

# ============================================================
# 12. 菜单
# ============================================================
func _on_menu() -> void:
	var popup = _make_popup("MenuPopup", 200, 320)
	var vbox = _popup_vbox(popup)
	_add_popup_title(vbox, "📋 菜单")

	var btns = [
		{"text": "💾 存档", "cb": func(): popup.queue_free(); _do_save_game()},
		{"text": "📂 读档", "cb": func(): popup.queue_free(); _do_load_game()},
		{"text": "📜 角色详情", "cb": func(): popup.queue_free(); _show_character_sheet()},
		{"text": "🏠 返回主菜单", "cb": func(): popup.queue_free(); get_tree().change_scene_to_file("res://scenes/main_menu.tscn")},
		{"text": "关闭", "cb": popup.queue_free},
	]
	for bd in btns:
		var btn = Button.new(); btn.text = bd.text; btn.custom_minimum_size = Vector2(0, 40)
		btn.pressed.connect(bd.cb); vbox.add_child(btn)

	add_child(popup)


# ============================================================
# 募兵处理
# ============================================================
func _on_recruit_troops() -> void:
	var char = GameState.current_character
	var max_troops = char.get("max_troops", {})
	if max_troops.is_empty():
		return

	var popup2 := _make_popup("RecruitTroops", 320, 280)
	var vbox2 := _popup_vbox(popup2)
	_add_popup_title(vbox2, "⚔ 招募家兵")

	# 兵种选择
	var type_label := Label.new()
	type_label.text = "选择兵种："
	vbox2.add_child(type_label)

	var type_option := OptionButton.new()
	var available_types: Array[String] = []
	for ttype in CharacterManager.TROOP_TYPES:
		var tdata = CharacterManager.TROOP_TYPES[ttype]
		var lvl = char.social_level
		var limit = max_troops.get(ttype, 0)
		if lvl >= tdata.min_level and limit > 0:
			var troops = char.get("household_troops", {})
			if troops is int:
				troops = {"步兵": troops, "车兵": 0, "王师": 0}
			var current = troops.get(ttype, 0)
			type_option.add_item("%s (%d/%d) — %d石/人" % [ttype, current, limit, tdata.cost])
			available_types.append(ttype)
	type_option.custom_minimum_size = Vector2(0, 32)
	vbox2.add_child(type_option)

	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox2.add_child(info)

	var input := LineEdit.new()
	input.placeholder_text = "输入数量..."
	input.custom_minimum_size = Vector2(0, 32)
	vbox2.add_child(input)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox2.add_child(btn_row)

	var confirm_btn := Button.new()
	confirm_btn.text = "确认招募"
	confirm_btn.custom_minimum_size = Vector2(100, 32)
	VisualConfig.style_button(confirm_btn, 13)
	btn_row.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(80, 32)
	VisualConfig.style_button(cancel_btn, 13)
	btn_row.add_child(cancel_btn)

	var result_label := Label.new()
	vbox2.add_child(result_label)

	# 更新info当选择变化时
	type_option.item_selected.connect(func(idx: int):
		if idx < 0 or idx >= available_types.size():
			return
		var sel = available_types[idx]
		var tdata = CharacterManager.TROOP_TYPES[sel]
		var troops = char.get("household_troops", {})
		if troops is int:
			troops = {"步兵": troops, "车兵": 0, "王师": 0}
		var current = troops.get(sel, 0)
		var limit = max_troops.get(sel, 0)
		info.text = "%s：%s\n当前：%d/%d | 每人：%d石" % [sel, tdata.desc, current, limit, tdata.cost]
	)
	# Trigger initial info
	if available_types.size() > 0:
		type_option.select(0)
		type_option.item_selected.emit(0)

	cancel_btn.pressed.connect(popup2.queue_free)
	confirm_btn.pressed.connect(func():
		var idx = type_option.selected
		if idx < 0 or idx >= available_types.size():
			result_label.text = "请选择兵种！"
			return
		var sel_type = available_types[idx]
		var amount = int(input.text) if input.text.is_valid_int() else 0
		if amount <= 0:
			result_label.text = "请输入有效的数量！"
			return
		var result = CharacterManager.recruit_troops(char, amount, sel_type)
		result_label.text = result.get("message", "")
		if result.get("success"):
			input.editable = false
			confirm_btn.disabled = true
			type_option.disabled = true
			_add_log("⚔ " + result.message)
			_refresh_display()
	)

	add_child(popup2)


func _do_save_game() -> void:
	var msg = GameState.save_game()
	_add_log(msg)
	_refresh_display()

func _do_load_game() -> void:
	var msg = GameState.load_game()
	# 读档后从完整史册重建屏幕日志（否则屏幕只剩"读档成功"一行，与史册分叉）
	_restore_log()
	_add_log(msg)
	_refresh_display()
	# 重新初始化界面
	_main_char_milestones.clear()
	_debt_seasons = 0

func _restore_log() -> void:
	event_log.clear()
	for line in GameState.full_log:
		event_log.append_text(line)
	_trim_log()
func _show_character_sheet() -> void:
	var char = GameState.current_character
	if char.is_empty(): return

	var popup = _make_popup("CharSheet", 300, 360)
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 12; scroll.offset_top = 12; scroll.offset_right = -12; scroll.offset_bottom = -12
	popup.get_child(1).add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	_add_popup_title(vbox, "📜 角色详情")

	var info = ""
	info += "姓名：%s%s · %s氏\n" % [char.surname, char.get("name", ""), char.get("clan", "")]
	info += "民族：%s\n" % char.ethnicity
	info += "身份：%s（Lv%d）\n" % [CharacterManager.get_social_display(char), char.social_level]
	info += "职业：%s\n" % char.get("profession", "")
	var sheet_age = CharacterManager.get_character_age(char)
	info += "年龄：%d岁\n" % sheet_age
	info += "阶段：%s\n" % TimeManager.get_life_stage_name(TimeManager.get_life_stage(sheet_age))
	info += "出生：公元前%d年\n" % abs(char.birth_year)

	if CharacterManager.is_married(char):
		var s = char.relationships.spouse
		info += "\n—— 配偶 ——\n%s%s·%s氏（%d岁）\n" % [s.surname, s.name, s.clan, s.age]

	var children = CharacterManager.get_character_children(char)
	if not children.is_empty():
		info += "\n—— 子女 ——\n"
		for c in children:
			if c.get("is_alive", true):
				var ca = GameState.current_year - c.birth_year
				var gender_str = "女" if c.gender == "female" else "子"
				var c_skills = c.get("skills", [])
				var skill_str = ""
				if not c_skills.is_empty():
					skill_str = " [" + ", ".join(c_skills) + "]"
				var bonus_str = ""
				if c.get("education_bonus", 0) > 0:
					bonus_str = " 教养+" + str(c.education_bonus)
				info += "%s%s（%s，%d岁）%s%s\n" % [c.surname, c.name, gender_str, ca, skill_str, bonus_str]

	info += "\n—— 属性 ——\n"
	for attr in ["con", "int", "str", "cha", "vir", "luk"]:
		var val = char.attributes.get(attr, 10)
		info += "%s：%d（%+d）\n" % [CharacterManager.get_attr_display(attr), val, DiceSystem.attr_to_bonus(val)]

	info += "\n—— 状态 ——\n"
	info += "健康：%d/100 | 声望：%d | 势力：%d\n" % [char.derived.get("health", 100), char.reputation, char.derived.get("power", 0)]
	info += "野心：%d | 财富：%d 石\n" % [char.derived.get("ambition", 0), GameState.family_data.wealth]

	info += "\n—— 技能 ——\n"
	if char.skills.is_empty():
		info += "暂无\n"
	else:
		for s in char.skills: info += "· %s\n" % s

	var rtl = RichTextLabel.new(); rtl.text = info; rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rtl.bbcode_enabled = true; rtl.fit_content = true
	vbox.add_child(rtl)

	var cb = Button.new(); cb.text = "关闭"; cb.custom_minimum_size = Vector2(0, 36)
	cb.pressed.connect(popup.queue_free); vbox.add_child(cb)

	add_child(popup)

# ============================================================
# 死亡与继承人
# ============================================================
func _show_death_menu() -> void:
	disable_all_buttons()
	var char = GameState.current_character
	var heir = CharacterManager.get_heir(char)

	var popup = _make_popup("DeathMenu", 200, 200)
	var vbox = _popup_vbox(popup)
	_add_popup_title(vbox, "⚰ 人生落幕")
	var label = Label.new()
	label.text = "你走完了作为西周士族的一生。\n享年%d岁，声望%d。" % [CharacterManager.get_character_age(char), char.reputation]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(label)

	if not heir.is_empty():
		var heir_age = heir.get("current_age", 0)
		var heir_btn = Button.new()
		heir_btn.text = "👤 继承者：%s%s（%d岁）——继续家族传奇" % [heir.surname, heir.name, heir_age]
		heir_btn.custom_minimum_size = Vector2(0, 44)
		heir_btn.pressed.connect(func():
			popup.queue_free()
			_start_as_heir(char, heir)
		)
		vbox.add_child(heir_btn)
	else:
		var no_heir = Label.new()
		no_heir.text = "你未有成年的继承人。\n家族的故事到此结束……"
		no_heir.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(no_heir)

	var quit_btn = Button.new()
	quit_btn.text = "🏠 返回主菜单"
	quit_btn.custom_minimum_size = Vector2(0, 36)
	quit_btn.pressed.connect(func(): popup.queue_free(); get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	vbox.add_child(quit_btn)

	add_child(popup)

func _start_as_heir(old_char: Dictionary, heir: Dictionary) -> void:
	var new_char = CharacterManager.create_heir_character(old_char, heir)
	GameState.current_character = new_char
	GameState.family_data.wealth = int(GameState.family_data.wealth / 2)
	_cooldowns.clear()

	_add_log("新一代接过了家族的旗帜——%s%s·%s氏，时年%d岁。" % [
		new_char.surname, new_char.name, new_char.clan, new_char.age
	])
	_add_log("继承了家族财富 %d 石和声望 %d。" % [GameState.family_data.wealth, new_char.reputation])
	refresh_all(new_char)

func refresh_all(new_char: Dictionary) -> void:
	# 重新计算并刷新全部显示
	new_char.derived = CharacterManager._calculate_derived(new_char)
	GameState.current_character = new_char
	advance_btn.disabled = false; advance_btn.text = "⏳ 推进"
	work_btn.disabled = false; study_btn.disabled = false; social_btn.disabled = false
	marry_btn.disabled = false; ritual_btn.disabled = false; travel_btn.disabled = false
	hunt_btn.disabled = false; market_btn.disabled = false; teach_btn.disabled = false
	rest_btn.disabled = false; menu_btn.disabled = false
	_age_gate_buttons()
	_refresh_display()

func disable_all_buttons() -> void:
	advance_btn.disabled = true; advance_btn.text = "已故"
	work_btn.disabled = true; study_btn.disabled = true; social_btn.disabled = true
	marry_btn.disabled = true; ritual_btn.disabled = true; travel_btn.disabled = true
	hunt_btn.disabled = true; market_btn.disabled = true; teach_btn.disabled = true
	rest_btn.disabled = true; menu_btn.disabled = true

# ============================================================
# 人生志向系统
# ============================================================
func _show_ambition_picker() -> void:
	var popup = _make_popup("AmbitionPicker", 260, 240)
	var vbox = _popup_vbox(popup)
	_add_popup_title(vbox, "🎯 选择人生志向")
	var info = Label.new()
	info.text = "成人礼毕，你当立下人生志向。\n此志将指引你的一生——"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)
	var keys = ["wealth", "promotion", "fame", "family", "tranquil"]
	for key in keys:
		var amb = AMBITIONS[key]
		var btn = Button.new()
		btn.text = "%s %s —— %s" % [amb.icon, amb.name, amb.desc]
		btn.custom_minimum_size = Vector2(0, 36)
		btn.pressed.connect(_on_ambition_chosen.bind(key, popup))
		vbox.add_child(btn)
	var cb = Button.new()
	cb.text = "暂不立志（可日后选择）"
	cb.custom_minimum_size = Vector2(0, 36)
	cb.pressed.connect(func():
		popup.queue_free()
		_add_log("你决定暂不立志，先看看这个世界。")
	)
	vbox.add_child(cb)
	add_child(popup)

func _on_ambition_chosen(ambition_key: String, popup: CanvasLayer) -> void:
	popup.queue_free()
	_ambition_type = ambition_key
	var amb = AMBITIONS[ambition_key]
	_add_log("🎯 你立下了人生志向：「%s%s」——%s" % [amb.icon, amb.name, amb.desc])
	_refresh_display()

func _update_ambition_display() -> void:
	if _ambition_type.is_empty() or _ambition_achieved:
		return
	var amb = AMBITIONS.get(_ambition_type, {})
	if amb.is_empty():
		return
	var pct = int(_ambition_progress * 100)
	var char = GameState.current_character
	var detail = ""
	match amb.check:
		"wealth":
			detail = "（%d/200石）" % GameState.family_data.wealth
		"rank":
			detail = "（当前：%s）" % CharacterManager.get_social_display(char)
		"reputation":
			detail = "（%d/80）" % char.get("reputation", 0)
		"children":
			var children = CharacterManager.get_character_children(char)
			var adult_count = 0
			for c in children:
				if c.get("is_alive", true) and (GameState.current_year - c.birth_year) >= 16:
					adult_count += 1
			detail = "（%d/3人成年）" % adult_count
		"age":
			var age = CharacterManager.get_character_age(char)
			detail = "（%d/50岁）" % age
	if pct >= 100 and not _ambition_achieved:
		_on_ambition_fulfilled()

func _check_ambition_progress() -> void:
	if _ambition_type.is_empty() or _ambition_achieved:
		return
	var char = GameState.current_character
	var amb = AMBITIONS.get(_ambition_type, {})
	if amb.is_empty():
		return
	var progress = 0.0
	match amb.check:
		"wealth":
			progress = minf(1.0, float(GameState.family_data.wealth) / 200.0)
		"rank":
			progress = 1.0 if char.social_level >= 4 else (0.33 if char.social_level >= 3 else 0.0)
		"reputation":
			progress = minf(1.0, float(char.get("reputation", 0)) / 80.0)
		"children":
			var children = CharacterManager.get_character_children(char)
			var adult_count = 0
			for c in children:
				if c.get("is_alive", true) and (GameState.current_year - c.birth_year) >= 16:
					adult_count += 1
			progress = minf(1.0, float(adult_count) / 3.0)
		"age":
			var age = CharacterManager.get_character_age(char)
			progress = minf(1.0, float(age) / 50.0)
	_ambition_progress = progress
	if progress >= 1.0 and not _ambition_achieved:
		_on_ambition_fulfilled()

func _on_ambition_fulfilled() -> void:
	_ambition_achieved = true
	var amb = AMBITIONS.get(_ambition_type, {})
	var amb_name = amb.get("name", _ambition_type)
	var amb_icon = amb.get("icon", "🎯")
	_add_log("🎊 恭喜！你达成了人生志向：「%s%s」！" % [amb_icon, amb_name])
	var popup = _make_popup("AmbitionFulfilled", 250, 200)
	var vbox = _popup_vbox(popup)
	_add_popup_title(vbox, "🎊 志向达成！")
	var label = Label.new()
	label.text = "你实现了毕生追求——\n\n「%s%s」\n%s\n\n你已完成人生的一个重要篇章。\n你可以继续游戏，或以此为终点。" % [amb_icon, amb_name, amb.get("desc", "")]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(label)
	var cont_btn = Button.new()
	cont_btn.text = "▶ 继续人生"
	cont_btn.custom_minimum_size = Vector2(0, 36)
	cont_btn.pressed.connect(func():
		popup.queue_free()
		_add_log("志向虽已达成，人生仍将继续……")
	)
	vbox.add_child(cont_btn)
	var end_btn = Button.new()
	end_btn.text = "🏠 返回主菜单"
	end_btn.custom_minimum_size = Vector2(0, 36)
	end_btn.pressed.connect(func():
		popup.queue_free()
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	vbox.add_child(end_btn)
	add_child(popup)
	if _auto_mode:
		_on_toggle_auto()
	_refresh_display()

# ============================================================
# ============================================================
# 晋升系统
# ============================================================
func _on_power_promote() -> void:
	var char = GameState.current_character
	# 资历门槛：本等级任职未满规定年限，不许请迁（抗刷）
	var tenure = CharacterManager.get_tenure_years(char)
	var need = CharacterManager.tenure_requirement(char.social_level)
	if tenure < need:
		_add_log("你方就任未满 %d 年（已 %d 年），资历尚浅，不宜贸然请迁。" % [need, tenure])
		_refresh_display()
		return
	var r: Dictionary = CharacterManager.promote_character(char)
	if r.get("success", false):
		_add_log("📈 " + r.get("message", ""))
		char.profession = CharacterManager.SOCIAL_CLASSES[char.social_level].display
		_show_promotion_celebration()
	else:
		_add_log("晋升失败——" + r.get("message", ""))
	_refresh_display()

func _on_reputation_promote() -> void:
	var char = GameState.current_character
	var rep: int = char.derived.get("reputation", 0)
	var bonus: int = DiceSystem.attr_to_bonus(char.attributes.get("cha", 10))
	var result := DiceSystem.roll_dice("2d6", bonus, 0)
	match result.tier:
		0:
			CharacterManager.modify_reputation(char, 10)
			_add_log("📜 乡老们对你的德行赞不绝口，声名远播——声望+10。朝廷册命方是晋升之途。")
			_refresh_display()
		1:
			CharacterManager.modify_reputation(char, 5)
			_add_log("📜 你的声望得到了乡里认可——声望+5。唯望朝廷册命，方得升迁。")
			_refresh_display()
		2:
			_add_log("📜 乡老们认为你声望尚不足以请迁……还需努力。")
		3:
			_add_log("📜 乡老斥责你妄自尊大，声望-5。")
			CharacterManager.modify_reputation(char, -5)
	_refresh_display()

func _show_promotion_gate() -> void:
	"""晋升之门：四道门资格可视 + 正式请迁"""
	var char = GameState.current_character
	if char.is_empty():
		return
	var popup := _make_popup("PromotionGate", 250, 345)
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, "🗝 晋升之门")

	# ── 世袭门 ──
	var heir_label := Label.new()
	heir_label.text = "🏛 世袭\n    " + _gate_heir_text(char)
	heir_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(heir_label)

	# ── 举贤门（士→卿大夫）──
	var rep = char.derived.get("reputation", 0)
	var max_skill := 0
	for sk in char.get("skills", []):
		var parts: PackedStringArray = String(sk).split(":")
		if parts.size() == 2:
			max_skill = maxi(max_skill, int(parts[1]))
	var xiangwang = GameState.family_data.get("xiangwang", 0)
	var ju_label := Label.new()
	ju_label.text = "🌾 举贤（士→卿大夫）\n    声望≥60：%s   最高技能≥3：%s\n    乡望：%d/50（三年一大比）" % [
		"✓" if rep >= 60 else "✗",
		"✓" if max_skill >= 3 else "✗",
		xiangwang
	]
	ju_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(ju_label)

	# ── 受封门（卿→诸侯）──
	var kf = char.get("king_favor", 20)
	var mm = char.get("military_merit", 0)
	var pw = char.derived.get("power", 0)
	var feng_label := Label.new()
	feng_label.text = "🏰 受封（卿→诸侯）\n    王宠 %d/60：%s   军功 %d/3：%s   势力 %d/60：%s" % [
		kf, "✓" if kf >= 60 else "✗",
		mm, "✓" if mm >= 3 else "✗",
		pw, "✓" if pw >= 60 else "✗"
	]
	feng_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(feng_label)

	# 举贤/受封动作按钮（按等级显示）
	if char.social_level == 3:
		var ju_btn := Button.new()
		ju_btn.text = "🌾 应乡举大比"
		ju_btn.custom_minimum_size = Vector2(0, 30)
		ju_btn.pressed.connect(func():
			var r = CharacterManager._do_merit_recommendation(char)
			if r.get("success", false):
				_add_log("📜 " + r.get("message", ""))
				_show_promotion_celebration()
			else:
				_add_log("🌾 " + r.get("message", ""))
			popup.queue_free()
			_refresh_display()
		)
		vbox.add_child(ju_btn)
	if char.social_level == 4:
		var feng_btn := Button.new()
		feng_btn.text = "🏰 求王册封（耗王宠30）"
		feng_btn.custom_minimum_size = Vector2(0, 30)
		feng_btn.pressed.connect(func():
			var r = CharacterManager._do_enfeoffment(char)
			if r.get("success", false):
				_add_log("🏰 " + r.get("message", ""))
				_show_promotion_celebration()
			else:
				_add_log("🏰 " + r.get("message", ""))
			popup.queue_free()
			_refresh_display()
		)
		vbox.add_child(feng_btn)

	# ── 爵位线 ──
	var cur_nlvl = char.get("noble_level", 0)
	var cur_noble = char.get("noble_title", "")
	var next_noble := "男爵（首授）"
	match cur_nlvl:
		1: next_noble = "子爵"
		2: next_noble = "伯爵"
		3: next_noble = "侯爵"
		4: next_noble = "公爵（唯天命）"
	var noble_label := Label.new()
	noble_label.text = "👑 爵位：%s → 晋 %s\n    王宠 %d/40：%s   声望 %d/80：%s" % [
		("未列侯" if cur_noble == "" else cur_noble + "爵"),
		next_noble,
		char.get("king_favor", 20), "✓" if char.get("king_favor", 20) >= 40 else "✗",
		char.derived.get("reputation", 0), "✓" if char.derived.get("reputation", 0) >= 80 else "✗"
	]
	noble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(noble_label)
	if cur_nlvl < 4:
		var noble_btn := Button.new()
		noble_btn.text = "👑 朝觐晋爵（耗王宠20）"
		noble_btn.custom_minimum_size = Vector2(0, 30)
		noble_btn.pressed.connect(func():
			var r = CharacterManager.advance_noble_title(char)
			_add_log("👑 " + r.get("message", ""))
			popup.queue_free()
			_refresh_display()
		)
		vbox.add_child(noble_btn)

	# ── 历史事件 ──
	var ev_label := Label.new()
	ev_label.text = "📜 历史事件\n    " + _game_next_event_text()
	ev_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(ev_label)

	# 分隔 + 正式请迁
	var sep := HSeparator.new()
	vbox.add_child(sep)
	var promote_btn := Button.new()
	promote_btn.text = "📈 正式请迁（资历：士3年/卿5年/诸侯8年）"
	promote_btn.custom_minimum_size = Vector2(0, 32)
	promote_btn.pressed.connect(func():
		popup.queue_free()
		_on_power_promote()
	)
	vbox.add_child(promote_btn)
	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(0, 28)
	close_btn.pressed.connect(popup.queue_free)
	vbox.add_child(close_btn)
	add_child(popup)

func _gate_heir_text(char: Dictionary) -> String:
	"""世袭门：找继承人（先男后女、成人优先）"""
	var alive: Array = []
	for c in CharacterManager.get_character_children(char):
		if c.get("is_alive", true):
			alive.append(c)
	var heir = null
	for c in alive:
		if c.get("gender", "male") == "male":
			heir = c
			break
	if heir == null and not alive.is_empty():
		heir = alive[0]
	if heir == null:
		return "尚无子嗣，有待后继。"
	var age = GameState.current_year - heir.birth_year
	var adult_txt := "成年，可承袭" if age >= 20 else ("%d岁，未及冠" % age)
	return "嫡嗣 %s%s，%d岁——%s。" % [heir.surname, heir.name, age, adult_txt]

func _game_next_event_text() -> String:
	"""距下一历史事件窗口（P4-2 铺排前显示暂无大事）"""
	return "王畿安靖，暂无大事。"

func _do_farming() -> void:
	"""耕作生计：每季声望+1~2、财富+5~10石"""
	var char = GameState.current_character
	var rep = randi_range(1, 2)
	var grain = randi_range(5, 10)
	CharacterManager.modify_reputation(char, rep)
	CharacterManager.modify_wealth(grain)
	_add_log("🌾 你荷锄下田，勤耕不辍——收成 %d 石，乡里称颂（声望+%d）。" % [grain, rep])
	_refresh_display()

func _do_military_service() -> void:
	"""从军生计：军功+1（每季1次，限士及以下）"""
	var char = GameState.current_character
	if char.social_level > 3:
		_add_log("你已有官职在身，不宜轻从行伍。")
		return
	CharacterManager.modify_military_merit(char, 1)
	_add_log("⚔ 你应征从军戍边，操练之余立下汗马功劳——军功+1。")
	_refresh_display()

# ============================================================
# 朝觐周王
# ============================================================
func _on_attend_court() -> void:
	var char = GameState.current_character
	if char.is_empty():
		return
	_attended_court_this_season = true

	# 朝贡花费
	var tribute = 5
	if GameState.family_data.wealth < tribute:
		_add_log("无力备齐朝觐贡礼（需%d石），无法朝王。" % tribute)
		return
	CharacterManager.modify_wealth(-tribute)

	var cha_bonus = DiceSystem.attr_to_bonus(char.attributes.get("cha", 10))
	var roll = DiceSystem.roll_dice("2d6", cha_bonus, 0)
	var birth_state = char.get("birth_state", "周王畿")
	var positions = CharacterManager.COURT_POSITIONS.get(birth_state, CharacterManager.COURT_POSITIONS["default"])

	match roll.tier:
		0:  # 大成功——获得官职
			var current_pos = char.get("official_position", "")
			if current_pos.is_empty():
				var new_pos = positions[randi_range(0, positions.size() - 1)]
				char["official_position"] = new_pos
				CharacterManager.modify_reputation(char, 5)
				_add_log("朝觐大吉！受周王册命为" + new_pos + "——从此位列朝班。声望+5")
			else:
				var pos_idx = positions.find(current_pos)
				if pos_idx > 0:
					var higher = positions[pos_idx - 1]
					char["official_position"] = higher
					_add_log("朝觐大吉！受王命擢升为" + higher + "！声望+5")
				else:
					_add_log("朝觐应对得体，周王嘉许。声望+5")
				CharacterManager.modify_reputation(char, 5)
		1:  # 成功
			CharacterManager.modify_reputation(char, 2)
			_add_log("朝觐议事——与诸卿大夫共商国是，声望+2。")
		2:  # 平平
			_add_log("朝觐——朝中无事，肃立终日。")
		3:  # 失败
			CharacterManager.modify_reputation(char, -3)
			_add_log("朝觐失仪——被太史斥责，声望-3。")
	_refresh_display()

func _on_meet_king() -> void:
	var char = GameState.current_character
	var king: Dictionary = DynastyManager.get_current_king(GameState.current_year)
	var popup := _make_popup("MeetKing", 240, 220)
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, "👑 觐见%s" % king.get("name", "周王"))

	var info := Label.new()
	info.text = "%s·%s\n在位：%s\n声誉 %d —— 已获召见资格。" % [
		king.get("given_name", "?"), king.get("name", "周王"),
		king.get("era", "未知"), char.reputation
	]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	var seek_btn := Button.new()
	seek_btn.text = "⚔ 请命于王，求仕进身"
	seek_btn.custom_minimum_size = Vector2(0, 38)
	seek_btn.pressed.connect(_on_seek_promotion.bind(popup))
	vbox.add_child(seek_btn)

	var greet_btn := Button.new()
	greet_btn.text = "🙇 以礼相见（声誉+5）"
	greet_btn.custom_minimum_size = Vector2(0, 34)
	greet_btn.pressed.connect(_on_greet_king.bind(popup))
	vbox.add_child(greet_btn)

	var cb := Button.new(); cb.text = "告退"; cb.pressed.connect(popup.queue_free)
	vbox.add_child(cb)
	add_child(popup)

func _on_seek_promotion(popup: CanvasLayer) -> void:
	popup.queue_free()
	var char = GameState.current_character
	var king: Dictionary = DynastyManager.get_current_king(GameState.current_year)
	var bonus: int = DiceSystem.attr_to_bonus(char.attributes.get("cha", 10))
	var result := DiceSystem.roll_dice("2d6", bonus, 0)
	_met_king_this_season = true

	match result.tier:
		0:
			CharacterManager.modify_king_favor(char, 15)
			CharacterManager.modify_reputation(char, 15)
			_add_log("🎉 大成功！" + king.get("name", "周王") + "对你赞赏有加，许你异日恩典——王宠+15，声望+15。")
			_refresh_display()
		1:
			CharacterManager.modify_king_favor(char, 10)
			CharacterManager.modify_reputation(char, 10)
			_add_log("👑 " + king.get("name", "周王") + "认可了你的才干，言明日后重用——王宠+10，声望+10。")
			_refresh_display()
		2:
			_add_log("君王认为你尚需历练，暂不赐爵。声誉+5。日后再来。")
			CharacterManager.modify_reputation(char, 5)
			_refresh_display()
		3:
			CharacterManager.demote_character(char, 2)
			_add_log("💀 大祸临头！%s龙颜大怒，以不敬之罪将你贬为庶人！声誉-30。" % king.get("name", "周王"))
			CharacterManager.modify_reputation(char, -30)
			_refresh_display()
			_show_demotion_popup()

func _on_greet_king(popup: CanvasLayer) -> void:
	popup.queue_free()
	var char = GameState.current_character
	_met_king_this_season = true
	CharacterManager.modify_reputation(char, 5)
	var king: Dictionary = DynastyManager.get_current_king(GameState.current_year)
	_add_log("🙇 你以礼相见%s，君王对你留下了不错的印象。声誉+5" % king.get("name", "周王"))
	_refresh_display()

func _on_ambition_plot() -> void:
	var char = GameState.current_character
	_ambition_plotted = true
	var popup := _make_popup("AmbitionPlot", 250, 240)
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, "🌑 暗谋举事")

	var info := Label.new()
	info.text = "野心 %d —— 你在暗中联络心腹，\n密谋夺取更大的权力……\n\n此乃铤而走险之举。\n事成则一步登天，事败则身死族灭。" % char.ambition
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)

	var go_btn := Button.new()
	go_btn.text = "🗡 孤注一掷"
	go_btn.custom_minimum_size = Vector2(0, 40)
	go_btn.pressed.connect(_on_plot_execute.bind(popup))
	vbox.add_child(go_btn)

	var back_btn := Button.new()
	back_btn.text = "😰 罢了……从长计议"
	back_btn.custom_minimum_size = Vector2(0, 34)
	back_btn.pressed.connect(popup.queue_free)
	vbox.add_child(back_btn)

	add_child(popup)

func _on_plot_execute(popup: CanvasLayer) -> void:
	popup.queue_free()
	var char = GameState.current_character
	var bonus: int = DiceSystem.attr_to_bonus(char.ambition)
	if char.ambition >= 80:
		bonus -= 1
	var result := DiceSystem.roll_dice("2d6", bonus, 0)

	match result.tier:
		0:
			CharacterManager.modify_regency_power(char, 20)
			CharacterManager.modify_ambition(char, 8)
			_add_log("🌑 暗谋大获成功！你在暗中扳倒政敌，把持朝政——实权+20，野心+8！无人知晓真相……")
			_refresh_display()
		1:
			CharacterManager.modify_regency_power(char, 12)
			CharacterManager.modify_ambition(char, 5)
			_add_log("🌑 暗谋成功。你逐渐掌控国政机枢——实权+12，野心+5，但朝中已有流言……")
			_refresh_display()
		2:
			CharacterManager.demote_character(char, 2)
			_add_log("💀 阴谋败露！你的暗谋被人告发……念在你过往功劳，免去死罪，贬为庶人！声誉-20，野心归零。")
			CharacterManager.modify_reputation(char, -20)
			CharacterManager.modify_ambition(char, -char.ambition)
			_refresh_display()
			_show_demotion_popup()
		3:
			_add_log("💀⚰ 东窗事发！你的阴谋被周王知晓，以谋逆之罪处以极刑！")
			char.is_alive = false
			_refresh_display()
			_show_treason_death()

func _show_demotion_popup() -> void:
	var popup := _make_popup("DemotionPopup", 240, 180)
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, "📉 贬为庶人")
	var label := Label.new()
	label.text = "你失去了士的身份与特权。\n从今往后，需以庶人之身，\n从头再来……\n\n或许有朝一日，还能重返士林。"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(label)
	var ok_btn := Button.new()
	ok_btn.text = "😔 接受命运"
	ok_btn.custom_minimum_size = Vector2(0, 36)
	ok_btn.pressed.connect(popup.queue_free)
	vbox.add_child(ok_btn)
	add_child(popup)

func _show_treason_death() -> void:
	disable_all_buttons()
	var char = GameState.current_character
	var popup := _make_popup("TreasonDeath", 250, 220)
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, "⚰ 谋逆伏诛")
	var label := Label.new()
	label.text = "你因暗谋举事被处以极刑。\n\n%s%s·%s氏的一生，\n以最惨烈的方式终结。\n享年%d岁，声望%d。" % [
		char.surname, char.get("name", ""), char.get("clan", ""),
		CharacterManager.get_character_age(char), char.reputation
	]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(label)

	var heir: Dictionary = CharacterManager.get_heir(char)
	if not heir.is_empty():
		var heir_age: int = heir.get("current_age", 0)
		var heir_btn := Button.new()
		heir_btn.text = "👤 继承者：%s%s（%d岁）——延续家族血脉" % [heir.surname, heir.name, heir_age]
		heir_btn.custom_minimum_size = Vector2(0, 44)
		heir_btn.pressed.connect(func():
			popup.queue_free()
			_start_as_heir(char, heir)
		)
		vbox.add_child(heir_btn)
	else:
		var no_heir := Label.new()
		no_heir.text = "你未有继承人。\n家族从此断绝……"
		no_heir.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(no_heir)

	var quit_btn := Button.new()
	quit_btn.text = "🏠 返回主菜单"
	quit_btn.custom_minimum_size = Vector2(0, 36)
	quit_btn.pressed.connect(func(): popup.queue_free(); get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	vbox.add_child(quit_btn)

	add_child(popup)

func _show_promotion_celebration() -> void:
	var char = GameState.current_character
	var lvl = char.social_level
	var titles = {2: "🎊 免于奴隶之身", 3: "🎊 步入士林", 4: "🎊 擢升卿大夫", 5: "🎊 受封诸侯", 6: "🎊 天命所归"}
	var texts = {
		2: "从今日起，你不再是奴隶了。\n你是庶人——可耕可织、\n自由谋生、积累家业。\n\n新的人生已经开始……",
		3: "从今日起，你步入士林。\n可为官吏、可习六艺、\n可结交权贵、谋划前程。\n\n士途漫漫，且行且珍惜……",
		4: "从今日起，你不再只是士了。\n是卿大夫——可参与朝政、\n统领军队、拥有采邑。\n\n西周的新篇章已经展开……",
		5: "天子册封，你位列诸侯。\n一国之君，封疆裂土——\n治万民、统千军、朝天子。\n\n荣耀与责任同在！",
		6: "天命所归，你登基为天子！\n天下共主，万邦来朝——\n你的名字将铭刻史册。\n\n新的时代由你开创！",
	}
	var btns = {2: "🏡 开始新生", 3: "📜 踏上仕途", 4: "🏛 踏上大夫之路", 5: "🏰 前往封地", 6: "👑 君临天下"}
	var popup := _make_popup("PromotionCelebration", 240, 200)
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, titles.get(lvl, "🎊 跃迁成功"))
	var label := Label.new()
	label.text = texts.get(lvl, "你的身份发生了变化。")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(label)
	var ok_btn := Button.new()
	ok_btn.text = btns.get(lvl, "继续")
	ok_btn.custom_minimum_size = Vector2(0, 36)
	ok_btn.pressed.connect(popup.queue_free)
	vbox.add_child(ok_btn)
	add_child(popup)

# ============================================================
# 弹窗工具函数
# ============================================================

# ============================================================
func _make_popup(name: String, half_w: int, half_h: int) -> CanvasLayer:
	var popup = CanvasLayer.new(); popup.name = name
	var bg = ColorRect.new(); bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP   # 拦截弹窗外的穿透点击，防误触
	popup.add_child(bg)
	var panel = Panel.new(); panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -half_w; panel.offset_top = -half_h
	panel.offset_right = half_w; panel.offset_bottom = half_h
	popup.add_child(panel)
	# 竹简展开入场：以面板中心为轴缩放 + 渐入（复用 TWEEN_POPUP_IN 常量）
	panel.pivot_offset = Vector2(half_w, half_h)
	panel.scale = Vector2(0.94, 0.94)
	panel.modulate.a = 0.0
	popup.ready.connect(func():
		var tw := popup.create_tween()
		tw.set_parallel(true)
		tw.tween_property(panel, "scale", Vector2.ONE, VisualConfig.TWEEN_POPUP_IN)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "modulate:a", 1.0, VisualConfig.TWEEN_POPUP_IN)
	)
	return popup

func _popup_vbox(popup: CanvasLayer) -> VBoxContainer:
	var panel = popup.get_child(1)
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 12; vbox.offset_top = 12; vbox.offset_right = -12; vbox.offset_bottom = -12
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	return vbox

func _confirm(title: String, body: String, danger: bool, on_yes: Callable) -> void:
	"""通用二次确认弹层：高风险操作先确认再执行，避免误触不可逆"""
	var popup := _make_popup("Confirm", 210, 200)
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, title)
	var info := Label.new()
	info.text = body
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)
	var yes := Button.new()
	yes.text = "确定"
	yes.custom_minimum_size = Vector2(0, 36)
	yes.pressed.connect(func():
		popup.queue_free()
		on_yes.call()
	)
	var yes_styles := VisualConfig.make_button_stylebox()
	if danger:
		yes_styles["normal"] = yes_styles["normal"]  # 危险语义用朱砂强调文字
		yes.add_theme_color_override("font_color", VisualConfig.VERMILLION)
	yes.add_theme_stylebox_override("normal", yes_styles["normal"])
	yes.add_theme_stylebox_override("hover", yes_styles["hover"])
	yes.add_theme_stylebox_override("pressed", yes_styles["pressed"])
	vbox.add_child(yes)
	var no := Button.new()
	no.text = "再想想"
	no.custom_minimum_size = Vector2(0, 30)
	no.pressed.connect(popup.queue_free)
	vbox.add_child(no)
	add_child(popup)

# ============================================================
# P1-2 浮动数值提示（Toast）：来源控件旁上浮渐隐
# 金色=财富、朱砂=健康损耗、玉绿=成长
# ============================================================
func _float_text(anchor: Control, text: String, color: Color) -> void:
	if not is_instance_valid(anchor):
		return
	var toast_layer: CanvasLayer = null
	for child in get_children():
		if child is CanvasLayer and child.name == "ToastLayer":
			toast_layer = child
			break
	if toast_layer == null:
		toast_layer = CanvasLayer.new()
		toast_layer.name = "ToastLayer"
		add_child(toast_layer)
	var toast := preload("res://scripts/ui/toast.gd").new()
	toast_layer.add_child(toast)
	toast.show_toast(anchor, text, color)

# ============================================================
# 家族互动系统
# ============================================================
func _make_family_button(text: String, relation_type: String, member_data: Dictionary) -> Button:
	"""创建家族成员按钮行"""
	var btn := Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 22)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Flat label-like style
	var st := StyleBoxFlat.new()
	st.bg_color = Color.TRANSPARENT
	st.content_margin_left = 12
	btn.add_theme_stylebox_override("normal", st)
	var st_h := st.duplicate() as StyleBoxFlat
	st_h.bg_color = VisualConfig.BG_MID_BROWN
	btn.add_theme_stylebox_override("hover", st_h)

	btn.add_theme_color_override("font_color", VisualConfig.TEXT_IVORY)
	btn.add_theme_font_size_override("font_size", 12)

	btn.pressed.connect(_on_family_member_clicked.bind(relation_type, member_data))
	return btn


func _build_family_content() -> void:
	"""重建家族区域内容（每次 _refresh_display 调用）"""
	if not _family_vbox:
		return

	# 清空
	for child in _family_vbox.get_children():
		child.queue_free()

	var char = GameState.current_character
	if char.is_empty():
		return

	var player_age := CharacterManager.get_character_age(char)

	# ── 父母 ──
	if GameState.family_data.has("parents"):
		var parents = GameState.family_data.parents
		var heading_p := Label.new()
		heading_p.text = "── 父母 ──"
		heading_p.add_theme_color_override("font_color", VisualConfig.DARK_GOLD)
		heading_p.add_theme_font_size_override("font_size", 11)
		_family_vbox.add_child(heading_p)

		# 父亲
		var father = parents.father
		var f_alive: bool = father.get("is_alive", true)
		var f_status: String = "✓" if f_alive else "✗"
		var f_text := "父: %s%s · %d岁 %s" % [father.surname, father.name, CharacterManager._compute_age(father), f_status]
		var f_btn := _make_family_button(f_text, "father", father)
		f_btn.visible = f_alive
		_family_vbox.add_child(f_btn)

		# 母亲
		var mother = parents.mother
		var m_alive: bool = mother.get("is_alive", true)
		var m_status: String = "✓" if m_alive else "✗"
		var m_text := "母: %s%s · %d岁 %s" % [mother.surname, mother.name, CharacterManager._compute_age(mother), m_status]
		var m_btn := _make_family_button(m_text, "mother", mother)
		m_btn.visible = m_alive
		_family_vbox.add_child(m_btn)

	# ── 兄弟姐妹 ──
	var siblings: Array = GameState.family_data.get("siblings", [])
	if not siblings.is_empty():
		var heading_s := Label.new()
		heading_s.text = "── 兄弟姐妹 ──"
		heading_s.add_theme_color_override("font_color", VisualConfig.DARK_GOLD)
		heading_s.add_theme_font_size_override("font_size", 11)
		_family_vbox.add_child(heading_s)

		for sib in siblings:
			var alive: bool = sib.get("is_alive", true)
			var kin: String = CharacterManager.get_sibling_kinship(sib, player_age)
			var status_str: String = "✓" if alive else "✗"
			var s_text: String = "%s: %s%s · %d岁 %s" % [kin, sib.surname, sib.name, CharacterManager._compute_age(sib), status_str]
			var s_btn := _make_family_button(s_text, "sibling", sib)
			s_btn.visible = alive
			_family_vbox.add_child(s_btn)

	# ── 配偶 ──
	if CharacterManager.is_married(char):
		var spouse = char.relationships.spouse
		var heading_sp := Label.new()
		heading_sp.text = "── 配偶 ──"
		heading_sp.add_theme_color_override("font_color", VisualConfig.DARK_GOLD)
		heading_sp.add_theme_font_size_override("font_size", 11)
		_family_vbox.add_child(heading_sp)

		var preg_info = ""
		if spouse.get("is_pregnant", false):
			preg_info = "  🤰%d季" % spouse.get("pregnancy_remaining", 0)
		var sp_text := "配偶: %s%s · %d岁 · 忠诚：%s%s" % [spouse.surname, spouse.name, CharacterManager._compute_age(spouse), CharacterManager.loyalty_band(spouse.get("loyalty", 80)), preg_info]
		var sp_btn := _make_family_button(sp_text, "spouse", spouse)
		_family_vbox.add_child(sp_btn)

	# ── 子女 ──
	var children: Array = CharacterManager.get_character_children(char)
	if not children.is_empty():
		var heading_c := Label.new()
		heading_c.text = "── 子女 ──"
		heading_c.add_theme_color_override("font_color", VisualConfig.DARK_GOLD)
		heading_c.add_theme_font_size_override("font_size", 11)
		# 标记继承人
		var heir = CharacterManager.get_heir(char)
		var heir_name = heir.get("name", "")
		_family_vbox.add_child(heading_c)

		for child in children:
			var alive: bool = child.get("is_alive", true)
			var ca: int = GameState.current_year - child.birth_year
			var gender_str: String = "女" if child.gender == "female" else "子"
			var status_str: String = "✓" if alive else "✗"
			var is_di = child.get("mother_type", "wife") == "wife"
			var di_marker = "🟊" if is_di else "○"
			var heir_marker = " 👑" if child.get("is_heir", false) else ""
			var focus = child.get("education_focus", "")
			var c_text := "%s %s: %s%s · %d岁 %s%s" % [di_marker, gender_str, child.surname, child.name, ca, status_str, heir_marker]
			if focus != "":
				var prog = child.get("education_progress", 0)
				c_text += " [%s %d%%]" % [focus, prog]
			# 婚嫁状态
			if child.get("is_married_out", false):
				c_text += " （已嫁 · 聘礼%d石）" % child.get("bride_price", 0)
			elif child.has("spouse") and not child.spouse.is_empty():
				c_text += " （已娶 · 子妇%s氏）" % child.spouse.get("surname", "?")
			# 标记继承人
			if heir_name != "" and child.get("name", "") == heir_name and child.get("surname", "") == heir.get("surname", ""):
				child["is_heir"] = true
				c_text += " 👑"
			var c_btn := _make_family_button(c_text, "child", child)
			c_btn.visible = alive
			_family_vbox.add_child(c_btn)

		# ── 妾室 ──
		var concubines: Array = GameState.family_data.get("concubines", [])
		if not concubines.is_empty():
			var heading_cn := Label.new()
			heading_cn.text = "── 妾室 ──"
			heading_cn.add_theme_color_override("font_color", VisualConfig.DARK_GOLD)
			heading_cn.add_theme_font_size_override("font_size", 11)
			_family_vbox.add_child(heading_cn)
			for cn_idx in range(concubines.size()):
				var cn = concubines[cn_idx]
				var cn_alive: bool = cn.get("is_alive", true)
				if not cn_alive:
					continue
				var preg_info = ""
				if cn.get("is_pregnant", false):
					preg_info = "  🤰%d季" % cn.get("pregnancy_remaining", 0)
				var cn_text := "妾: %s%s · %d岁 · 忠诚：%s%s" % [cn.surname, cn.name, CharacterManager._compute_age(cn), CharacterManager.loyalty_band(cn.get("loyalty", 50)), preg_info]
				var cn_btn := _make_family_button(cn_text, "concubine", cn)
				cn_btn.visible = cn_alive
				_family_vbox.add_child(cn_btn)

		# ── 媵妾（诸侯）──
		var ying_qie: Array = GameState.family_data.get("ying_qie", [])
		if not ying_qie.is_empty():
			var heading_yq := Label.new()
			heading_yq.text = "── 媵妾 ──"
			heading_yq.add_theme_color_override("font_color", VisualConfig.DARK_GOLD)
			heading_yq.add_theme_font_size_override("font_size", 11)
			_family_vbox.add_child(heading_yq)
			for yq in ying_qie:
				if not yq.get("is_alive", true):
					continue
				var yq_preg: String = ""
				if yq.get("is_pregnant", false):
					yq_preg = "  🤰%d季" % yq.get("pregnancy_remaining", 0)
				var yq_text := "媵: %s%s · %d岁 · 忠诚：%s%s" % [yq.surname, yq.name, CharacterManager._compute_age(yq), CharacterManager.loyalty_band(yq.get("loyalty", 50)), yq_preg]
				var yq_btn := _make_family_button(yq_text, "ying_qie", yq)
				_family_vbox.add_child(yq_btn)
		# ── 夫人（天子）──
		var furens: Array = GameState.family_data.get("furens", [])
		if not furens.is_empty():
			var heading_fr := Label.new()
			heading_fr.text = "── 夫人 ──"
			heading_fr.add_theme_color_override("font_color", VisualConfig.DARK_GOLD)
			heading_fr.add_theme_font_size_override("font_size", 11)
			_family_vbox.add_child(heading_fr)
			for fr in furens:
				if not fr.get("is_alive", true):
					continue
				var fr_preg: String = ""
				if fr.get("is_pregnant", false):
					fr_preg = "  🤰%d季" % fr.get("pregnancy_remaining", 0)
				var fr_text := "夫人: %s%s · %d岁 · 忠诚：%s%s" % [fr.surname, fr.name, CharacterManager._compute_age(fr), CharacterManager.loyalty_band(fr.get("loyalty", 50)), fr_preg]
				var fr_btn := _make_family_button(fr_text, "furen", fr)
				_family_vbox.add_child(fr_btn)
		# ── 通房 ──
		var tongfangs: Array = GameState.family_data.get("tongfangs", [])
		if not tongfangs.is_empty():
			var heading_tf := Label.new()
			heading_tf.text = "── 通房 ──"
			heading_tf.add_theme_color_override("font_color", VisualConfig.DARK_GOLD)
			heading_tf.add_theme_font_size_override("font_size", 11)
			_family_vbox.add_child(heading_tf)
			for tf in tongfangs:
				if not tf.get("is_alive", true):
					continue
				var tf_preg: String = ""
				if tf.get("is_pregnant", false):
					tf_preg = "  🤰%d季" % tf.get("pregnancy_remaining", 0)
				var tf_text := "通房: %s%s · %d岁 · 忠诚：%s%s" % [tf.surname, tf.name, CharacterManager._compute_age(tf), CharacterManager.loyalty_band(tf.get("loyalty", 50)), tf_preg]
				var tf_btn := _make_family_button(tf_text, "tongfang", tf)
				_family_vbox.add_child(tf_btn)

	# 通知 ScrollContainer 重新计算内容高度
	if _family_vbox:
		_family_vbox.queue_sort()

func _on_family_member_clicked(relation_type: String, member_data: Dictionary) -> void:
	"""点击家族成员 → 弹出互动菜单"""
	if not member_data.get("is_alive", true):
		_add_log("此人已不在人世……")
		return

	var popup := _make_popup("FamilyInteract", 220, 280)
	var vbox := _popup_vbox(popup)

	# 标题
	var relation_icon: String = ""
	match relation_type:
		"father": relation_icon = "父"
		"mother": relation_icon = "母"
		"sibling": relation_icon = "亲"
		"spouse": relation_icon = "偶"
		"concubine": relation_icon = "妾"
		"furen": relation_icon = "夫人"
		"ying_qie": relation_icon = "媵"
		"tongfang": relation_icon = "通"
		"child": relation_icon = "子"
	_add_popup_title(vbox, relation_icon + " " + member_data.surname + member_data.name)

	# 信息行
	var info_text: String = ""
	match relation_type:
		"father":
			var prof: String = member_data.get("profession", "")
			info_text = "父 · %d岁 · %s" % [CharacterManager._compute_age(member_data), prof]
		"mother":
			info_text = "母 · %d岁" % CharacterManager._compute_age(member_data)
		"sibling":
			var player_age := CharacterManager.get_character_age(GameState.current_character)
			var kin: String = CharacterManager.get_sibling_kinship(member_data, player_age)
			info_text = "%s · %d岁" % [kin, CharacterManager._compute_age(member_data)]
		"spouse":
			info_text = "配偶 · %d岁" % CharacterManager._compute_age(member_data)
		"concubine":
			info_text = "妾室 · %d岁" % CharacterManager._compute_age(member_data)
		"furen":
			info_text = "夫人 · %d岁" % CharacterManager._compute_age(member_data)
		"ying_qie":
			info_text = "媵妾 · %d岁" % CharacterManager._compute_age(member_data)
		"tongfang":
			info_text = "通房 · %d岁" % CharacterManager._compute_age(member_data)
		"child":
			var ca: int = GameState.current_year - member_data.birth_year
			var gs: String = "女" if member_data.gender == "female" else "子"
			var is_di = member_data.get("mother_type", "wife") == "wife"
			var di_label = "嫡" if is_di else "庶"
			var heir_label = "（继承人）" if member_data.get("is_heir", false) else ""
			var edu = member_data.get("education_focus", "")
			var edu_str = " | 教育：" + edu if edu != "" else ""
			info_text = "%s · %d岁 · %s出%s%s" % [gs, ca, di_label, heir_label, edu_str]

	var info_label := Label.new()
	info_label.text = info_text
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	VisualConfig.style_small_label(info_label, 13)
	vbox.add_child(info_label)

	# 操作按钮
	var actions := _get_family_actions(relation_type, member_data)
	for action in actions:
		var btn := Button.new()
		btn.text = action.text
		btn.custom_minimum_size = Vector2(0, 30)
		VisualConfig.style_button(btn, 13)
		var btn_styles := VisualConfig.make_button_stylebox()
		btn.add_theme_stylebox_override("normal", btn_styles["normal"])
		btn.add_theme_stylebox_override("hover", btn_styles["hover"])
		btn.add_theme_stylebox_override("pressed", btn_styles["pressed"])
		# 冷却置灰：本季已做的动作禁用并标注
		var cd: String = action.get("cooldown", "")
		if not cd.is_empty() and not _can_act(cd):
			btn.disabled = true
			btn.text += "  ✓本季已做"
		btn.pressed.connect(func():
			popup.queue_free()
			# 已有入口冷却的动作自行守门，其余收敛到统一执行器
			if action.get("self_gated", false):
				action.callback.call()
			else:
				_run_family_act(action.get("cooldown", ""), "本季已做过，下季再来吧。", action.callback)
		)
		vbox.add_child(btn)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.custom_minimum_size = Vector2(0, 30)
	close_btn.pressed.connect(popup.queue_free)
	vbox.add_child(close_btn)

	add_child(popup)


func _get_family_actions(relation_type: String, member_data: Dictionary) -> Array:
	"""返回指定家族成员的可执行操作"""
	var actions: Array = []
	var char = GameState.current_character
	var player_age := CharacterManager.get_character_age(char)

	match relation_type:
		"father", "mother":
			if player_age < 20:
				actions.append({"text": "💰 要钱", "callback": func(): _on_ask_parents(), "cooldown": "ask_parents", "self_gated": true})
			actions.append({"text": "💬 交谈", "callback": func(): _do_family_talk(relation_type, member_data), "cooldown": "talk_" + relation_type})
			if relation_type == "father":
				actions.append({"text": "📜 聆听教诲", "callback": func(): _do_family_lesson(member_data), "cooldown": "lesson_father"})
			else:
				actions.append({"text": "🏠 回家探望", "callback": func(): _do_family_visit(member_data), "cooldown": "visit_mother"})
		"sibling":
			actions.append({"text": "💬 交谈", "callback": func(): _do_family_talk(relation_type, member_data), "cooldown": "talk_sibling"})
			actions.append({"text": "🎁 赠礼（5石）", "callback": func(): _on_gift_sibling(_find_sibling_index(member_data)), "cooldown": "gift_sibling_" + str(_find_sibling_index(member_data))})
			actions.append({"text": "🤝 结盟", "callback": func(): _do_family_ally(member_data), "cooldown": "ally_sibling"})
			actions.append({"text": "💔 决裂", "callback": func(): _on_break_ally_sibling(_find_sibling_index(member_data)), "cooldown": "ally_sibling"})
		"spouse":
			actions.append({"text": "💬 交谈", "callback": func(): _do_family_talk(relation_type, member_data), "cooldown": "talk_spouse"})
			actions.append({"text": "❤️ 亲近", "callback": func(): _do_family_bond(member_data), "cooldown": "bond_spouse"})
			actions.append({"text": "🌙 求子（同房）", "callback": func(): _do_try_for_baby_wife(member_data), "cooldown": "try_baby_wife", "self_gated": true})
			actions.append({"text": "🔍 考察忠诚", "callback": func(): _do_test_spouse_loyalty(member_data, "wife", 0), "cooldown": "test_spouse_loyalty", "self_gated": true})
			actions.append({"text": "🎁 赏赐博欢心", "callback": func(): _do_boost_spouse_loyalty(member_data, "wife", 0), "cooldown": "boost_spouse_loyalty", "self_gated": true})
		"child":
			actions.append({"text": "💬 谈心", "callback": func(): _do_family_talk(relation_type, member_data), "cooldown": "talk_child"})
			# 子索引：按 member_data 在子女数组里查位置（教导冷却按人区分）
			var children: Array = CharacterManager.get_character_children(char)
			var child_idx := -1
			for i in range(children.size()):
				if children[i].name == member_data.name and children[i].surname == member_data.surname:
					child_idx = i
					break
			# 教导：self_gated 取消免费——冷却在选科确认时才打点，打开弹窗后取消不消耗
			actions.append({"text": "👨‍🏫 教导", "callback": func(): _do_teach_specific_child(member_data), "cooldown": "teach_child_" + str(child_idx), "self_gated": true})
			actions.append({"text": "🎯 定方向", "callback": func(): _on_set_child_direction(member_data), "cooldown": "set_child_direction", "self_gated": true})
			# 成年子女婚嫁
			var child_age: int = GameState.current_year - member_data.get("birth_year", GameState.current_year)
			if child_age >= 16:
				if member_data.gender == "female" and not member_data.get("is_married_out", false):
					actions.append({"text": "🏮 嫁女", "callback": func(): _do_marry_out_daughter(member_data), "cooldown": "marry_child_" + member_data.name, "self_gated": true})
				elif member_data.gender == "male" and not member_data.has("spouse"):
					actions.append({"text": "💒 娶妻", "callback": func(): _do_marry_in_son(member_data), "cooldown": "marry_child_" + member_data.name, "self_gated": true})
		"concubine":
			actions.append({"text": "💬 交谈", "callback": func(): _do_family_talk(relation_type, member_data), "cooldown": "talk_concubine"})
			actions.append({"text": "❤️ 亲近", "callback": func(): _do_concubine_bond(member_data), "cooldown": "bond_concubine"})
			# 妾索引：按 member_data 在妾室数组里查位置（求子冷却按人区分）
			var concubines: Array = GameState.family_data.get("concubines", [])
			var cn_idx := -1
			for i in range(concubines.size()):
				if concubines[i].name == member_data.name and concubines[i].surname == member_data.surname:
					cn_idx = i
					break
			actions.append({"text": "🌙 求子（同房）", "callback": func(): _do_try_for_baby_concubine(member_data), "cooldown": "try_baby_concubine_" + str(cn_idx), "self_gated": true})
			actions.append({"text": "🔍 考察忠诚", "callback": func(): _do_test_spouse_loyalty(member_data, "concubine", cn_idx), "cooldown": "test_concubine_" + str(cn_idx), "self_gated": true})
			actions.append({"text": "🎁 安抚博欢心", "callback": func(): _do_boost_spouse_loyalty(member_data, "concubine", cn_idx), "cooldown": "boost_concubine_" + str(cn_idx), "self_gated": true})
		"furen", "ying_qie", "tongfang":
			actions.append({"text": "💬 交谈", "callback": func(): _do_family_talk(relation_type, member_data), "cooldown": "talk_" + relation_type})
			actions.append({"text": "❤️ 亲近", "callback": func(): _do_family_bond(member_data, "bond_" + relation_type), "cooldown": "bond_" + relation_type})
			# 求子：按成员索引区分冷却（统一判定入口）
			var consort_arr: Array = GameState.family_data.get(
				"furens" if relation_type == "furen" else ("ying_qie" if relation_type == "ying_qie" else "tongfangs"), [])
			var cs_idx := -1
			for i in range(consort_arr.size()):
				if consort_arr[i].name == member_data.name and consort_arr[i].surname == member_data.surname:
					cs_idx = i
					break
			if cs_idx >= 0:
				actions.append({"text": "🌙 求子（同房）", "callback": func(): _do_try_for_baby(relation_type, cs_idx), "cooldown": "try_baby_" + relation_type + "_" + str(cs_idx), "self_gated": true})

	return actions


func _do_family_talk(relation_type: String, member_data: Dictionary) -> void:
	"""家族交谈：CHA掷骰 → 声望+"""
	var char = GameState.current_character
	var cha: int = char.attributes.get("cha", 10)
	var bonus: int = DiceSystem.attr_to_bonus(cha)
	var roll_result: Dictionary = DiceSystem.roll_dice("2d6", bonus, 8)
	var r: int = roll_result.final_value

	var name_str: String = member_data.surname + member_data.name
	if r >= 10:
		CharacterManager.modify_reputation(char, 2)
		CharacterManager.modify_ambition(char, 1)
		_add_log("💬 与%s交谈甚欢，声望+2。" % name_str)
	elif r >= 6:
		CharacterManager.modify_reputation(char, 1)
		_add_log("💬 与%s聊了几句，声望+1。" % name_str)
	else:
		_add_log("💬 与%s话不投机……" % name_str)
	# 兄弟姐妹交谈增加好感
	if relation_type == "sibling":
		var sib_idx = _find_sibling_index(member_data)
		if sib_idx >= 0:
			var aff_gain = 1 + randi_range(0, 4)  # +1~5
			CharacterManager.modify_sibling_affection(sib_idx, aff_gain)
	# 与妻妾交谈记入本季亲密（忠诚衰减豁免）
	if relation_type in ["spouse", "concubine", "furen", "ying_qie", "tongfang"]:
		var c_idx := _find_consort_index(relation_type, member_data)
		if c_idx >= 0:
			_mark_intimate(relation_type, c_idx)
	_mark_acted("talk_" + relation_type)


func _do_family_lesson(member_data: Dictionary) -> void:
	"""聆听父亲教诲：VIR掷骰 → 技能+1"""
	var char = GameState.current_character
	var vir: int = char.attributes.get("vir", 10)
	var bonus := DiceSystem.attr_to_bonus(vir)
	var roll_result: Dictionary = DiceSystem.roll_dice("2d6", bonus, 8)
	var r: int = roll_result.final_value

	if r >= 10:
		var skills_list: Array = ["礼法", "书数", "射御", "乐诗"]
		var picked: String = skills_list[randi_range(0, skills_list.size() - 1)]
		# 手动添加技能（add_char_skill 不存在，内联处理）
		var found_skill := false
		for j in range(char.skills.size()):
			if char.skills[j].begins_with(picked + ":"):
				var lvl_str: String = char.skills[j].get_slice(":", 1)
				var lvl: int = lvl_str.to_int() if lvl_str.is_valid_int() else 1
				char.skills[j] = picked + ":" + str(lvl + 1)
				found_skill = true
				break
		if not found_skill:
			char.skills.append(picked + ":1")
		_add_log("📜 聆听父亲教诲，学有所成——%s+1！" % picked)
	elif r >= 6:
		CharacterManager.modify_reputation(char, 1)
		_add_log("📜 父亲的话语让你受益良多，声望+1。")
	else:
		_add_log("📜 父亲的教诲太过深奥，你未能领会……")
	_mark_acted("lesson_father")


func _do_family_visit(member_data: Dictionary) -> void:
	"""探望母亲：VIR掷骰 → 回复健康"""
	var char = GameState.current_character
	var vir: int = char.attributes.get("vir", 10)
	var bonus := DiceSystem.attr_to_bonus(vir)
	var roll_result: Dictionary = DiceSystem.roll_dice("2d6", bonus, 8)
	var r: int = roll_result.final_value

	if r >= 10:
		CharacterManager.modify_health(char, 5)
		_add_log("🏠 回家探望母亲，倍感温暖——健康+5。")
	elif r >= 6:
		CharacterManager.modify_health(char, 2)
		_add_log("🏠 母亲嘘寒问暖——健康+2。")
	else:
		_add_log("🏠 母亲正在忙碌，未能长谈。")
	_mark_acted("visit_mother")


func _do_family_ally(member_data: Dictionary) -> void:
	"""与兄弟姐妹结盟：CHA掷骰 → 加入allies"""
	var char = GameState.current_character
	var cha: int = char.attributes.get("cha", 10)
	var bonus: int = DiceSystem.attr_to_bonus(cha)
	var roll_result: Dictionary = DiceSystem.roll_dice("2d6", bonus, 8)
	var r: int = roll_result.final_value

	var name_str: String = member_data.surname + member_data.name
	if r >= 10:
		char.relationships.allies.append(member_data)
		CharacterManager.modify_reputation(char, 3)
		_add_log("🤝 %s愿与你同进退——声望+3！" % name_str)
	elif r >= 6:
		CharacterManager.modify_reputation(char, 1)
		_add_log("🤝 与%s达成默契——声望+1。" % name_str)
	else:
		CharacterManager.modify_reputation(char, -1)
		_add_log("🤝 %s婉拒了你的结盟提议……声望-1。" % name_str)
	_mark_acted("ally_sibling")


func _do_concubine_bond(member_data: Dictionary) -> void:
	"""与妾室亲近：CHA掷骰 → 回复健康"""
	var char = GameState.current_character
	var cha: int = char.attributes.get("cha", 10)
	var bonus: int = DiceSystem.attr_to_bonus(cha)
	var roll_result: Dictionary = DiceSystem.roll_dice("2d6", bonus, 8)
	var r: int = roll_result.final_value
	var name_str: String = member_data.surname + member_data.name
	if r >= 10:
		CharacterManager.modify_health(char, 3)
		CharacterManager.modify_ambition(char, 1)
		_add_log("❤️ 妾室%s柔情似水——健康+3。" % name_str)
	elif r >= 6:
		CharacterManager.modify_health(char, 1)
		_add_log("❤️ 与妾室%s温存片刻——健康+1。" % name_str)
	else:
		_add_log("❤️ 今日妾室%s身体不适……" % name_str)
	GameState.current_character["_last_bond_season"] = 0
	_mark_acted("bond_concubine")

func _do_test_spouse_loyalty(member_data: Dictionary, mother_type: String = "wife", mother_index: int = 0) -> void:
	"""考察妻妾忠诚（模糊评估）"""
	var cooldown_id: String = "test_spouse_loyalty" if mother_type == "wife" else "test_concubine_%d" % mother_index
	if not _can_act(cooldown_id):
		_add_log("本季已考察过这位妻妾的忠诚，下季再来吧。")
		return
	var result = CharacterManager.test_spouse_loyalty(GameState.current_character, mother_type, mother_index)
	_add_log(result.get("message", ""))
	_mark_acted(cooldown_id)
	_refresh_display()

func _do_boost_spouse_loyalty(member_data: Dictionary, mother_type: String = "wife", mother_index: int = 0) -> void:
	"""赏赐博妻妾欢心"""
	var cooldown_id: String = "boost_spouse_loyalty" if mother_type == "wife" else "boost_concubine_%d" % mother_index
	if not _can_act(cooldown_id):
		_add_log("本季已赏赐过这位妻妾，下季再来吧。")
		return
	_mark_intimate(mother_type, mother_index)   # 赏赐记入本季亲密
	var result = CharacterManager.boost_spouse_loyalty(GameState.current_character, mother_type, mother_index)
	if result.get("success", false):
		_add_log("🎁 " + result.message)
	else:
		_add_log(result.message)
	_mark_acted(cooldown_id)
	
func _do_try_for_baby(mother_type: String, index: int) -> void:
	"""统一同房/求子判定：CON掷骰定档；大成功必孕（force_success），消除"大成功却未受孕"矛盾"""
	var cooldown_id: String = "try_baby_wife" if mother_type == "wife" else "try_baby_%s_%d" % [mother_type, index]
	if not _can_act(cooldown_id):
		_add_log("本季已同房求过子，下季再来吧。")
		return
	var char = GameState.current_character
	var con: int = char.attributes.get("con", 10)
	var bonus: int = DiceSystem.attr_to_bonus(con)
	var roll_result: Dictionary = DiceSystem.roll_dice("2d6", bonus, 0)
	var r: int = roll_result.final_value
	var tier: int = roll_result.tier
	_mark_intimate(mother_type, index)   # 本季已同房，忠诚衰减豁免
	var m_name := CharacterManager._get_mother_name(mother_type, index)
	match tier:
		0:  # 大成功——必孕
			var preg_result = CharacterManager.start_pregnancy(mother_type, index, true)
			_add_log("🌙 " + preg_result.message + "（CON %d -> %d，大吉！）" % [con, r])
		1:  # 成功——走正常受孕概率
			var preg_result = CharacterManager.start_pregnancy(mother_type, index, false)
			_add_log("🌙 " + preg_result.message + "（CON %d -> %d）" % [con, r])
		2:  # 未成孕
			_add_log("🌙 与%s同房——然未成孕，静待机缘。（CON %d）" % [m_name, con])
		_:  # 疲惫
			CharacterManager.modify_health(char, -1)
			_add_log("🌙 房事伤身——略感疲惫，健康-1。（CON %d）" % con)
	_mark_acted(cooldown_id)
	_refresh_display()

func _do_try_for_baby_wife(member_data: Dictionary) -> void:
	"""与妻子求子：统一判定入口"""
	_do_try_for_baby("wife", 0)

func _do_try_for_baby_concubine(member_data: Dictionary) -> void:
	"""与妾室求子：统一判定入口"""
	var concubines: Array = GameState.family_data.get("concubines", [])
	var cn_idx := -1
	for i in range(concubines.size()):
		if concubines[i].name == member_data.name and concubines[i].surname == member_data.surname:
			cn_idx = i
			break
	if cn_idx < 0:
		_add_log("找不到该妾室……")
		return
	_do_try_for_baby("concubine", cn_idx)
func _do_marry_out_daughter(member_data: Dictionary) -> void:
	"""嫁女操作"""
	var cooldown_id = "marry_child_" + member_data.get("name", "")
	if not _can_act(cooldown_id):
		_add_log("本季已为子女操办过婚事，下季再来吧。")
		return
	var result = CharacterManager.marry_out_daughter(GameState.current_character, member_data)
	_add_log(result.get("message", ""))
	if result.get("success", false):
		_mark_acted(cooldown_id)
	_refresh_display()

func _do_marry_in_son(member_data: Dictionary) -> void:
	"""为子娶妻操作"""
	var cooldown_id = "marry_child_" + member_data.get("name", "")
	if not _can_act(cooldown_id):
		_add_log("本季已为子女操办过婚事，下季再来吧。")
		return
	var result = CharacterManager.marry_in_son(GameState.current_character, member_data)
	_add_log(result.get("message", ""))
	if result.get("success", false):
		_mark_acted(cooldown_id)
	_refresh_display()

func _do_family_bond(member_data: Dictionary, cooldown_id: String = "bond_spouse") -> void:
	"""与配偶亲近：CHA掷骰 → 回复健康"""
	var char = GameState.current_character
	var cha: int = char.attributes.get("cha", 10)
	var bonus: int = DiceSystem.attr_to_bonus(cha)
	var roll_result: Dictionary = DiceSystem.roll_dice("2d6", bonus, 8)
	var r: int = roll_result.final_value

	var name_str: String = member_data.surname + member_data.name
	if r >= 10:
		CharacterManager.modify_health(char, 3)
		CharacterManager.modify_ambition(char, 1)
		_add_log("❤️ 与%s共度温馨时光——健康+3。" % name_str)
	elif r >= 6:
		CharacterManager.modify_health(char, 1)
		_add_log("❤️ 与%s互诉衷肠——健康+1。" % name_str)
	else:
		CharacterManager.modify_ambition(char, -1)
		_add_log("❤️ 今日与%s有些疏远……" % name_str)
	# 亲近记入本季亲密（忠诚衰减豁免）
	var b_type := cooldown_id.trim_prefix("bond_")
	if b_type == "spouse":
		b_type = "wife"
	var b_idx := _find_consort_index(b_type, member_data)
	if b_idx >= 0:
		_mark_intimate(b_type, b_idx)
	GameState.current_character["_last_bond_season"] = 0
	_mark_acted(cooldown_id)


func _on_set_child_direction(child: Dictionary) -> void:
	"""为子女设置教育方向"""
	if not _can_act("set_child_direction"):
		_add_log("本季已为子女定过教育方向，下季再来吧。")
		return
	var age = GameState.current_year - child.get("birth_year", GameState.current_year)
	var popup := _make_popup("ChildDirection", 230, 220)
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, "🎯 %s%s的教育方向" % [child.surname, child.name])
	var info := Label.new()
	var cur_focus = child.get("education_focus", "")
	info.text = "年龄：%d岁 | 当前方向：%s" % [age, cur_focus if cur_focus != "" else "未定"]
	vbox.add_child(info)
	if age < 6:
		var tip := Label.new()
		tip.text = "（6岁前仅启蒙，不可指定方向）"
		tip.add_theme_color_override("font_color", Color.RED)
		vbox.add_child(tip)
	var dirs = CharacterManager.EDUCATION_DIRECTIONS
	for dir_key in dirs:
		var d = dirs[dir_key]
		var btn := Button.new()
		btn.text = "%s %s——%s" % [d.icon, dir_key, d.desc]
		btn.custom_minimum_size = Vector2(0, 32)
		btn.disabled = age < 6
		btn.pressed.connect(func():
			var result = CharacterManager.set_child_education_direction(child, dir_key)
			popup.queue_free()
			_add_log(result.message)
			_mark_acted("set_child_direction")
			_refresh_display()
		)
		vbox.add_child(btn)
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.pressed.connect(popup.queue_free)
	vbox.add_child(cancel_btn)
	add_child(popup)

func _do_teach_specific_child(member_data: Dictionary) -> void:
	"""教指定子女"""
	var char = GameState.current_character
	var children: Array = CharacterManager.get_character_children(char)
	var idx: int = -1
	for i in range(children.size()):
		if children[i].name == member_data.name and children[i].surname == member_data.surname:
			idx = i
			break
	if idx < 0:
		_add_log("找不到该子女。")
		return
	_show_teach_picker_for_child(idx)


func _show_teach_picker_for_child(child_index: int) -> void:
	"""为指定子女显示教子弹窗"""
	var char = GameState.current_character
	var children: Array = CharacterManager.get_character_children(char)
	if child_index < 0 or child_index >= children.size():
		return
	var child = children[child_index]
	var popup := _make_popup("TeachChild", 220, 180)
	var vbox := _popup_vbox(popup)
	_add_popup_title(vbox, "教导 " + child.surname + child.name)

	var subjects := ["礼法", "书数", "射御", "乐诗"]
	for subj in subjects:
		var btn := Button.new()
		btn.text = subj
		btn.custom_minimum_size = Vector2(0, 30)
		VisualConfig.style_button(btn, 13)
		var btn_styles := VisualConfig.make_button_stylebox()
		btn.add_theme_stylebox_override("normal", btn_styles["normal"])
		btn.add_theme_stylebox_override("hover", btn_styles["hover"])
		btn.add_theme_stylebox_override("pressed", btn_styles["pressed"])
		btn.pressed.connect(func():
			popup.queue_free()
			# 选科确认入口守门：本季已教导过此子则拒绝（取消免费，打开弹窗不消耗）
			if not _can_act("teach_child_" + str(child_index)):
				_add_log("本季已教导过此子，下季再来吧。")
				return
			var result := CharacterManager.educate_child(char, child_index, subj)
			_add_log("👨‍🏫 " + result.message)
			_mark_acted("teach_child_" + str(child_index))
			_refresh_display()
		)
		vbox.add_child(btn)

	var close_btn := Button.new()
	close_btn.text = "取消"
	close_btn.custom_minimum_size = Vector2(0, 30)
	close_btn.pressed.connect(popup.queue_free)
	vbox.add_child(close_btn)
	add_child(popup)


func _add_popup_title(vbox: VBoxContainer, text: String) -> void:
	var title = Label.new(); title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
