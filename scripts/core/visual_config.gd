# VisualConfig.gd — 视觉配置（Autoload）
# 西周五色体系 + 字体定义
extends Node

# ============================================================
# 色彩系统 — 西周青铜美学
# ============================================================
# 背景色系
const BG_LACQUER: Color = Color("1a1410")     # 漆器黑 — 主背景
const BG_DARK_BROWN: Color = Color("2d2418")  # 深棕 — 面板底色
const BG_MID_BROWN: Color = Color("3d3226")   # 中棕 — 次级面板

# 金属色系
const GOLD: Color = Color("daa520")           # 金色 — 标题文字
const DARK_GOLD: Color = Color("c9a96e")      # 暗金 — 次要标题
const BRONZE: Color = Color("b8860b")         # 古铜 — 边框/分割线
const BRONZE_GREEN_DARK: Color = Color("4a6741")  # 青铜暗绿 — 按钮常态
const BRONZE_GREEN_MID: Color = Color("6b8e5a")   # 青铜中绿 — 按钮悬停
const BRONZE_GREEN_LIGHT: Color = Color("8fbc8f") # 铜锈浅绿 — 成功提示

# 文字色系
const TEXT_BONE: Color = Color("f5f0e8")      # 骨白 — 正文
const TEXT_IVORY: Color = Color("e8dcc8")     # 象牙白 — 次要文字
const TEXT_SAND: Color = Color("d2c4a7")      # 沙土色 — 三级文字

# 语义色
const VERMILLION: Color = Color("c41e3a")     # 朱砂红 — 健康条/警告
const DEEP_RED: Color = Color("8b3a3a")       # 深红 — 危险
const OCHRE: Color = Color("a0522d")          # 赭石 — 野心条
const JADE: Color = Color("5b8c5a")           # 玉石绿 — 正面/成功

# 弹窗遮罩
const OVERLAY_DIM: Color = Color(0, 0, 0, 0.7)

# ============================================================
# 进度条颜色（按语义分配）
# ============================================================
const BAR_HEALTH: Color = VERMILLION
const BAR_REPUTATION: Color = BRONZE_GREEN_MID
const BAR_POWER: Color = DARK_GOLD
const BAR_AMBITION: Color = OCHRE

# ============================================================
# 字体配置 — 单字体 Variable Font 派生多层级
# ============================================================
# 金文大篆体 — 西周青铜铭文风格（标题专用）
const FONT_TITLE_PATH: String = "res://resources/fonts/jinwen.ttf"

# 思源宋体 Variable Font — 唯一正文字体源，其余层级通过 FontVariation 派生
const FONT_SERIF_VF: String = "res://resources/fonts/NotoSerifSC-VF.ttf"

# ============================================================
# 动画时长
# ============================================================
const TWEEN_POPUP_IN: float = 0.2
const TWEEN_POPUP_OUT: float = 0.15
const TWEEN_HOVER: float = 0.1
const TWEEN_PRESS: float = 0.05
const TWEEN_SEASON: float = 0.5
const TWEEN_DEATH: float = 2.0

# ============================================================
# 字体缓存 — 在 _ready() 中初始化
# ============================================================
var title_font: Font = null            # 金文大篆体 ~48px 标题（缺失时降级为特粗）
var base_font: FontFile = null         # 思源宋体 Variable Font（仅加载一次）
var heading_font: FontVariation = null # 派生 weight 700 ~24px 面板标题
var body_font: FontVariation = null    # 派生 weight 400 ~15px 正文
var label_font: FontVariation = null   # 派生 weight 400 ~13px 属性标签
var button_font: FontVariation = null  # 派生 weight 600 ~15px 按钮
var number_font: FontVariation = null  # 派生 weight 400 ~14px 数值

func _ready() -> void:
	# 正文层级：从单一 Variable Font 派生（仅 load 一次，避免重复加载字体文件）
	if ResourceLoader.exists(FONT_SERIF_VF):
		base_font = load(FONT_SERIF_VF)
		heading_font = _derive_font(700)
		body_font = _derive_font(400)
		label_font = _derive_font(400)
		button_font = _derive_font(600)
		number_font = _derive_font(400)
		print("VisualConfig: 思源宋体 Variable Font 已加载，派生 5 个层级")
	else:
		print("VisualConfig: 思源宋体 Variable Font 未找到，使用系统默认字体")

	# 标题字体：金文大篆体（西周青铜铭文风格）
	if ResourceLoader.exists(FONT_TITLE_PATH):
		title_font = load(FONT_TITLE_PATH)
		print("VisualConfig: 金文大篆体已加载 — 西周青铜铭文风格标题")
	elif base_font:
		title_font = _derive_font(900)  # 降级：Variable Font 特粗
		print("VisualConfig: 金文字体未找到，标题降级为思源宋体特粗")

# ============================================================
# 字体派生 — 从单一 Variable Font 派生不同粗细层级
# ============================================================
func _derive_font(weight: int) -> FontVariation:
	"""从 base_font 派生一个指定粗细的字体实例（不重复 load 字体文件）"""
	var fv := FontVariation.new()
	fv.base_font = base_font
	fv.variation_opentype = {"wght": weight}
	return fv


# ============================================================
# 辅助: 设置 Label 字体 + 颜色 + 大小
# ============================================================
func style_title_label(label: Label, size: int = 48) -> void:
	label.add_theme_font_override("font", title_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", GOLD)

func style_heading_label(label: Label, size: int = 24) -> void:
	label.add_theme_font_override("font", heading_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", DARK_GOLD)

func style_body_label(label: Label, size: int = 15) -> void:
	label.add_theme_font_override("font", body_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TEXT_BONE)

func style_small_label(label: Label, size: int = 13) -> void:
	label.add_theme_font_override("font", label_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TEXT_IVORY)

func style_button(btn: Button, size: int = 15) -> void:
	btn.add_theme_font_override("font", button_font)
	btn.add_theme_font_size_override("font_size", size)


# ============================================================
# U-3 共享 StyleBox 缓存：全项目仅 3 个 StyleBoxFlat 实例
# 替代各处每次新建 make_button_stylebox()（40+ 实例 → 3 个共享）
# ============================================================
var _btn_styles_cached: Dictionary = {}

func get_button_stylebox() -> Dictionary:
	if _btn_styles_cached.is_empty():
		_btn_styles_cached = make_button_stylebox()
	return _btn_styles_cached


func style_panel(panel: Panel, border_color: Color = BRONZE) -> void:
	"""为 Panel 节点应用西周面板样式"""
	panel.add_theme_stylebox_override("panel", make_panel_stylebox(BG_DARK_BROWN, border_color))


func style_progress_bar(pb: ProgressBar, fill_color: Color) -> void:
	"""为 ProgressBar 应用西周进度条样式"""
	var styles := make_progressbar_style(fill_color)
	pb.add_theme_stylebox_override("background", styles["background"])
	pb.add_theme_stylebox_override("fill", styles["fill"])


# ============================================================
# 内容纹理路径常量（立绘/背景/图标 — 游戏内容资源，非 UI 装饰）
# ============================================================
const TEX_PORTRAIT_PLAYER: String = "res://resources/textures/portraits/player_young_shi.png"
const TEX_PORTRAIT_WIFE: String = "res://resources/textures/portraits/npc_wife.png"
const TEX_PORTRAIT_FATHER: String = "res://resources/textures/portraits/npc_father.png"
const TEX_PORTRAIT_COLLEAGUE: String = "res://resources/textures/portraits/npc_colleague.png"

const TEX_BG_HAOJING: String = "res://resources/textures/backgrounds/city_haojing.png"
const TEX_BG_LUOYI: String = "res://resources/textures/backgrounds/city_luoyi.png"
const TEX_BG_ZHOUGONG: String = "res://resources/textures/backgrounds/zhougong_teaching.png"

const TEX_ICON_RITUAL: String = "res://resources/textures/icons/skill_ritual.png"
const TEX_ICON_ARCHERY: String = "res://resources/textures/icons/skill_archery.png"
const TEX_ICON_WRITING: String = "res://resources/textures/icons/skill_writing.png"
const TEX_ICON_MUSIC: String = "res://resources/textures/icons/skill_music.png"
const TEX_ICON_STRATEGY: String = "res://resources/textures/icons/skill_strategy.png"
const TEX_ICON_MEDICINE: String = "res://resources/textures/icons/skill_medicine.png"
const TEX_ICON_PERSUASION: String = "res://resources/textures/icons/skill_persuasion.png"

const TEX_EVENT_COURT: String = "res://resources/textures/events/event_court_audience.png"
const TEX_EVENT_MARTIAL: String = "res://resources/textures/events/event_martial_test.png"

# 城市→背景纹理映射
const CITY_BACKGROUNDS: Dictionary = {
	"镐京": TEX_BG_HAOJING,
	"洛邑": TEX_BG_LUOYI,
}

# 技能→图标纹理映射
const SKILL_ICONS: Dictionary = {
	"礼法": TEX_ICON_RITUAL,
	"射御": TEX_ICON_ARCHERY,
	"书数": TEX_ICON_WRITING,
	"乐": TEX_ICON_MUSIC,
	"兵法": TEX_ICON_STRATEGY,
	"医术": TEX_ICON_MEDICINE,
	"游说": TEX_ICON_PERSUASION,
}


# ============================================================
# 便捷：加载纹理
# ============================================================
func load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null


func get_city_background(city_name: String) -> Texture2D:
	var tex_path: String = CITY_BACKGROUNDS.get(city_name, TEX_BG_HAOJING)
	return load_texture(tex_path)


func get_skill_icon(skill_name: String) -> Texture2D:
	var tex_path: String = SKILL_ICONS.get(skill_name, "")
	if tex_path.is_empty():
		return null
	return load_texture(tex_path)


# ============================================================
# StyleBox 生成 — 用代码创建 StyleBoxFlat（无需纹理）
# ============================================================
func make_panel_stylebox(bg_color: Color = BG_DARK_BROWN,
		border_color: Color = BRONZE, border_width: int = 2,
		corner_radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_width_left = border_width
	sb.border_width_right = border_width
	sb.border_width_top = border_width
	sb.border_width_bottom = border_width
	sb.border_color = border_color
	sb.corner_radius_top_left = corner_radius
	sb.corner_radius_top_right = corner_radius
	sb.corner_radius_bottom_left = corner_radius
	sb.corner_radius_bottom_right = corner_radius
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func make_button_stylebox(normal_color: Color = BRONZE_GREEN_DARK,
		hover_color: Color = BRONZE_GREEN_MID,
		press_color: Color = Color("3d5235"),
		border_color: Color = BRONZE,
		corner_radius: int = 4) -> Dictionary:
	"""返回 {normal, hover, pressed} StyleBoxFlat 字典"""
	var styles := {}

	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = normal_color
	sb_normal.border_width_left = 1
	sb_normal.border_width_right = 1
	sb_normal.border_width_top = 1
	sb_normal.border_width_bottom = 1
	sb_normal.border_color = border_color
	sb_normal.corner_radius_top_left = corner_radius
	sb_normal.corner_radius_top_right = corner_radius
	sb_normal.corner_radius_bottom_left = corner_radius
	sb_normal.corner_radius_bottom_right = corner_radius
	sb_normal.content_margin_left = 16
	sb_normal.content_margin_right = 16
	sb_normal.content_margin_top = 6
	sb_normal.content_margin_bottom = 6
	styles["normal"] = sb_normal

	var sb_hover := sb_normal.duplicate() as StyleBoxFlat
	sb_hover.bg_color = hover_color
	styles["hover"] = sb_hover

	var sb_press := sb_normal.duplicate() as StyleBoxFlat
	sb_press.bg_color = press_color
	styles["pressed"] = sb_press

	return styles


func make_progressbar_style(fill_color: Color, bg_color: Color = BG_MID_BROWN,
		corner_radius: int = 3) -> Dictionary:
	"""返回 {background, fill} StyleBoxFlat 字典"""
	var styles := {}

	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = bg_color
	sb_bg.corner_radius_top_left = corner_radius
	sb_bg.corner_radius_top_right = corner_radius
	sb_bg.corner_radius_bottom_left = corner_radius
	sb_bg.corner_radius_bottom_right = corner_radius
	styles["background"] = sb_bg

	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = fill_color
	sb_fill.corner_radius_top_left = corner_radius
	sb_fill.corner_radius_top_right = corner_radius
	sb_fill.corner_radius_bottom_left = corner_radius
	sb_fill.corner_radius_bottom_right = corner_radius
	styles["fill"] = sb_fill

	return styles


func make_popup_panel() -> StyleBoxFlat:
	"""弹窗面板样式 — 深色底+铜色边"""
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1a1410")  # 漆器黑
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = DARK_GOLD
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.shadow_size = 8
	sb.shadow_color = Color(0, 0, 0, 0.6)
	return sb


# ============================================================
# 全局主题应用 — 对场景根调用此函数自动美化所有控件
# ============================================================
func apply_global_theme(root: Node) -> void:
	"""递归遍历场景树，自动为已知控件类型应用西周主题"""
	_apply_to_node(root)


func _apply_to_node(node: Node) -> void:
	# Label
	if node is Label:
		var label := node as Label
		if not label.has_meta("styled"):
			label.add_theme_font_override("font", body_font)
			label.add_theme_font_size_override("font_size", 15)
			label.add_theme_color_override("font_color", TEXT_BONE)
			label.set_meta("styled", true)

	# Button
	if node is Button:
		var btn := node as Button
		if not btn.has_meta("styled"):
			btn.add_theme_font_override("font", button_font)
			btn.add_theme_font_size_override("font_size", 15)
			btn.add_theme_color_override("font_color", TEXT_BONE)
			var btn_styles := make_button_stylebox()
			btn.add_theme_stylebox_override("normal", btn_styles["normal"])
			btn.add_theme_stylebox_override("hover", btn_styles["hover"])
			btn.add_theme_stylebox_override("pressed", btn_styles["pressed"])
			btn.set_meta("styled", true)

	# Panel
	if node is Panel:
		var panel := node as Panel
		if not panel.has_meta("styled"):
			panel.add_theme_stylebox_override("panel", make_panel_stylebox())
			panel.set_meta("styled", true)

	# PanelContainer
	if node is PanelContainer:
		var pc := node as PanelContainer
		if not pc.has_meta("styled"):
			pc.add_theme_stylebox_override("panel", make_panel_stylebox())
			pc.set_meta("styled", true)

	# ProgressBar
	if node is ProgressBar:
		var pb := node as ProgressBar
		if not pb.has_meta("styled"):
			var fill_color := BAR_HEALTH
			var n := pb.name.to_lower()
			if "rep" in n or "reputation" in n:
				fill_color = BAR_REPUTATION
			elif "power" in n:
				fill_color = BAR_POWER
			elif "ambition" in n:
				fill_color = BAR_AMBITION
			var pb_styles := make_progressbar_style(fill_color)
			pb.add_theme_stylebox_override("background", pb_styles["background"])
			pb.add_theme_stylebox_override("fill", pb_styles["fill"])
			pb.set_meta("styled", true)

	# 递归子节点
	for child in node.get_children():
		_apply_to_node(child)
