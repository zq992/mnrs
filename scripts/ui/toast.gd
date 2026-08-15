# Toast.gd — 浮动数值提示（P1-2 行动结果空间反馈）
# 在来源控件旁弹出上浮渐隐的数值提示，玩家无需读日志即可感知变化。
# 颜色沿用西周五色语义：金色=财富、朱砂=健康损耗、玉绿=成长。
extends CanvasLayer

func show_toast(anchor: Control, text: String, color: Color) -> void:
	if not is_instance_valid(anchor):
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.position = anchor.global_position + Vector2(0, -8)
	lbl.z_index = 100
	add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 28.0, 0.8)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(0.3)
	tw.chain().tween_callback(lbl.queue_free)
