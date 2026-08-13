#!/usr/bin/env python3
with open('scripts/ui/hud.gd', 'r', encoding='utf-8') as f:
    hud = f.read()

# Find and replace _on_category_pressed
old = '''func _on_category_pressed(cat_id: String, actions: Array) -> void:
\t"""点击分类按钮 — 弹出子操作菜单"""
\tif _category_popup:
\t\t_category_popup.queue_free()
\t\t_category_popup = null
\t\treturn  # 点击同一分类按钮关闭弹窗

\tvar popup := _make_popup("CatMenu", 100, 60 + actions.size() * 32)
\t_category_popup = popup
\tvar vbox := _popup_vbox(popup)
\t# 将面板定位到底部（CanvasLayer 不支持 offset_left/top，改用 Panel）
\tvar panel: Panel = popup.get_child(1)
\tpanel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
\tvar _ph: int = 60 + actions.size() * 32
\tpanel.offset_top = -(_ph + 20)
\tpanel.offset_bottom = 60
\tpanel.offset_left = -100
\tpanel.offset_right = 100

\tfor action in actions:
\t\tvar action_btn: Button = null
\t\tmatch action:
\t\t\t"work": action_btn = _make_action_btn("\U0001f4bc 履职", _on_work)
\t\t\t"study": action_btn = _make_action_btn("\U0001f4da 修习", _on_study)
\t\t\t"social": action_btn = _make_action_btn("\U0001fa1d 交游", _on_socialize)
\t\t\t"ask_parents": action_btn = _make_action_btn("\U0001f4b0 要钱", _on_ask_parents)
\t\t\t"marry": action_btn = _make_action_btn("\U0001f48d 议亲", _on_marry)
\t\t\t"teach": action_btn = _make_action_btn("\U0001f468‍\U0001f3eb 教子", _on_teach_child)
\t\t\t"ritual": action_btn = _make_action_btn("\U0001f3db 祭祀", _on_ritual)
\t\t\t"travel": action_btn = _make_action_btn("\U0001f5fa 出行", _on_travel)
\t\t\t"hunt": action_btn = _make_action_btn("\U0001f3f9 田猎", _on_hunt)
\t\t\t"market": action_btn = _make_action_btn("\U0001f4e6 市集", _on_market)
\t\tif action_btn:
\t\t\tvbox.add_child(action_btn)

\t# 条件：势力晋升路径（power >= 50 且是士）
\tvar char_for_cat := GameState.current_character
\tif not char_for_cat.is_empty():
\t\tif CharacterManager.can_promote(char_for_cat) and char_for_cat.social_level == 3:
\t\t\tvar pp_btn := _make_action_btn("\U0001f4c8 请迁（势力已足）", _on_power_promote)
\t\t\tvbox.add_child(pp_btn)
\t\t# 条件：声望路径（reputation >= 90 且是士，每季限一次）
\t\tif char_for_cat.reputation >= 90 and char_for_cat.social_level == 3 and not _met_king_this_season:
\t\t\tvar mk_btn := _make_action_btn("\U0001f451 觐见国君", _on_meet_king)
\t\t\tvbox.add_child(mk_btn)
\t\t# 条件3: 野心隐藏路径（ambition >= 70 且是士，一生一次）
\t\tif char_for_cat.ambition >= 70 and char_for_cat.social_level == 3 and not _ambition_plotted:
\t\t\tvar ab_btn := _make_action_btn("\U0001f311 暗谋举事（铤而走险）", _on_ambition_plot)
\t\t\tvbox.add_child(ab_btn)

\t# 在分类按钮上方弹出


\tadd_child(popup)


func _make_action_btn'''

assert old in hud, "old _on_category_pressed not found"

new = '''func _on_category_pressed(cat_id: String, actions: Array) -> void:
\t"""点击分类按钮 — 弹出子操作菜单"""
\tif _category_popup:
\t\t_category_popup.queue_free()
\t\t_category_popup = null
\t\treturn  # 点击同一分类按钮关闭弹窗

\t# 预计算条件按钮数量，确保弹窗高度正确
\tvar extra_count := 0
\tvar char_for_cat := GameState.current_character
\tif not char_for_cat.is_empty():
\t\tif CharacterManager.can_promote(char_for_cat) and char_for_cat.social_level == 3:
\t\t\textra_count += 1
\t\tif char_for_cat.reputation >= 90 and char_for_cat.social_level == 3 and not _met_king_this_season:
\t\t\textra_count += 1
\t\tif char_for_cat.ambition >= 70 and char_for_cat.social_level == 3 and not _ambition_plotted:
\t\t\textra_count += 1

\tvar total_actions := actions.size() + extra_count
\tvar popup := _make_popup("CatMenu", 100, 60 + total_actions * 32)
\t_category_popup = popup
\tvar vbox := _popup_vbox(popup)
\t# 将面板定位到底部（CanvasLayer 不支持 offset_left/top，改用 Panel）
\tvar panel: Panel = popup.get_child(1)
\tpanel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
\tvar _ph: int = 60 + total_actions * 32
\tpanel.offset_top = -(_ph + 20)
\tpanel.offset_bottom = 60
\tpanel.offset_left = -100
\tpanel.offset_right = 100

\tfor action in actions:
\t\tvar action_btn: Button = null
\t\tmatch action:
\t\t\t"work": action_btn = _make_action_btn("\U0001f4bc 履职", _on_work)
\t\t\t"study": action_btn = _make_action_btn("\U0001f4da 修习", _on_study)
\t\t\t"social": action_btn = _make_action_btn("\U0001fa1d 交游", _on_socialize)
\t\t\t"ask_parents": action_btn = _make_action_btn("\U0001f4b0 要钱", _on_ask_parents)
\t\t\t"marry": action_btn = _make_action_btn("\U0001f48d 议亲", _on_marry)
\t\t\t"teach": action_btn = _make_action_btn("\U0001f468‍\U0001f3eb 教子", _on_teach_child)
\t\t\t"ritual": action_btn = _make_action_btn("\U0001f3db 祭祀", _on_ritual)
\t\t\t"travel": action_btn = _make_action_btn("\U0001f5fa 出行", _on_travel)
\t\t\t"hunt": action_btn = _make_action_btn("\U0001f3f9 田猎", _on_hunt)
\t\t\t"market": action_btn = _make_action_btn("\U0001f4e6 市集", _on_market)
\t\tif action_btn:
\t\t\tvbox.add_child(action_btn)

\t# 条件按钮
\tif not char_for_cat.is_empty():
\t\tif CharacterManager.can_promote(char_for_cat) and char_for_cat.social_level == 3:
\t\t\tvar pp_btn := _make_action_btn("\U0001f4c8 请迁（势力已足）", _on_power_promote)
\t\t\tvbox.add_child(pp_btn)
\t\tif char_for_cat.reputation >= 90 and char_for_cat.social_level == 3 and not _met_king_this_season:
\t\t\tvar mk_btn := _make_action_btn("\U0001f451 觐见国君", _on_meet_king)
\t\t\tvbox.add_child(mk_btn)
\t\tif char_for_cat.ambition >= 70 and char_for_cat.social_level == 3 and not _ambition_plotted:
\t\t\tvar ab_btn := _make_action_btn("\U0001f311 暗谋举事（铤而走险）", _on_ambition_plot)
\t\t\tvbox.add_child(ab_btn)

\tadd_child(popup)


func _make_action_btn'''

hud = hud.replace(old, new, 1)

with open('scripts/ui/hud.gd', 'w', encoding='utf-8') as f:
    f.write(hud)

print('Fixed popup sizing')
