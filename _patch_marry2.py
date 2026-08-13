#!/usr/bin/env python3
"""Add arranged marriage + family separation system to hud.gd"""

FILE = r"E:\技术资料\项目\mnrs\scripts\ui\hud.gd"

with open(FILE, "r", encoding="utf-8") as f:
    content = f.read()

# === 1. Replace _on_marry to show two-mode choice ===
old1 = """func _on_marry() -> void:
\tvar char = GameState.current_character
\tif CharacterManager.is_married(char):
\t\t_add_log("你已有配偶——%s%s·%s氏。" % [char.relationships.spouse.surname, char.relationships.spouse.name, char.relationships.spouse.clan])
\t\treturn

\tvar popup = _make_popup("MarryPicker", 210, 240)
\tvar vbox = _popup_vbox(popup)
\t_add_popup_title(vbox, "💍 择偶议亲（同姓不婚）")

\tvar eligible = CharacterManager.get_eligible_surnames(char)
\tvar clans_map = {
\t\t"姬": ["周", "鲁", "晋", "卫", "郑", "燕"], "姜": ["吕", "齐", "许", "申"],
\t\t"姒": ["杞", "鄫", "褒"], "妫": ["陈", "田"], "嬴": ["秦", "赵", "徐"],
\t\t"姞": ["南燕", "密"], "妘": ["郧", "邬"], "姚": ["姚"],
\t}

\tfor surname in eligible:
\t\tvar clans = clans_map.get(surname, [surname])
\t\tfor clan in clans:
\t\t\tvar dowry_cost = 50 + randi_range(0, 80)
\t\t\tvar btn = Button.new()
\t\t\tbtn.text = "%s姓·%s氏（聘礼约%d石）" % [surname, clan, dowry_cost]
\t\t\tbtn.custom_minimum_size = Vector2(0, 34)
\t\t\tbtn.pressed.connect(_on_marry_propose.bind(surname, clan, dowry_cost, popup))
\t\t\tvbox.add_child(btn)

\tvar cb = Button.new(); cb.text = "取消"; cb.pressed.connect(popup.queue_free); vbox.add_child(cb)
\tadd_child(popup)"""

assert old1 in content, "_on_marry function not found"

new1 = """func _on_marry() -> void:
\tvar char = GameState.current_character
\tif CharacterManager.is_married(char):
\t\t_add_log("你已有配偶——%s%s·%s氏。" % [char.relationships.spouse.surname, char.relationships.spouse.name, char.relationships.spouse.clan])
\t\treturn

\t# 先选择婚配方式
\tvar popup = _make_popup("MarryMode", 220, 160)
\tvar vbox = _popup_vbox(popup)
\t_add_popup_title(vbox, "💍 议亲（同姓不婚）")

\tvar info := Label.new()
\tinfo.text = "西周婚配，有父母之命与自行求娶两途。"
\tvbox.add_child(info)

\tvar parent_btn := Button.new()
\tparent_btn.text = "👴 父母之命（无需聘礼，父母包办）"
\tparent_btn.custom_minimum_size = Vector2(0, 36)
\tparent_btn.pressed.connect(_on_arranged_marriage.bind(popup))
\tvbox.add_child(parent_btn)

\tvar self_btn := Button.new()
\tself_btn.text = "💍 自己求娶（自选对象，需付聘礼）"
\tself_btn.custom_minimum_size = Vector2(0, 36)
\tself_btn.pressed.connect(_on_self_marry.bind(popup))
\tvbox.add_child(self_btn)

\tvar cb = Button.new(); cb.text = "取消"; cb.pressed.connect(popup.queue_free); vbox.add_child(cb)
\tadd_child(popup)

func _on_self_marry(popup: CanvasLayer) -> void:
\t"""自己求娶——显示可选对象列表"""
\tpopup.queue_free()
\tvar char = GameState.current_character
\tvar popup2 = _make_popup("MarryPicker", 210, 240)
\tvar vbox = _popup_vbox(popup2)
\t_add_popup_title(vbox, "💍 自己求娶——选择对象")

\tvar eligible = CharacterManager.get_eligible_surnames(char)
\tvar clans_map = {
\t\t"姬": ["周", "鲁", "晋", "卫", "郑", "燕"], "姜": ["吕", "齐", "许", "申"],
\t\t"姒": ["杞", "鄫", "褒"], "妫": ["陈", "田"], "嬴": ["秦", "赵", "徐"],
\t\t"姞": ["南燕", "密"], "妘": ["郧", "邬"], "姚": ["姚"],
\t}

\tfor surname in eligible:
\t\tvar clans = clans_map.get(surname, [surname])
\t\tfor clan in clans:
\t\t\tvar dowry_cost = 50 + randi_range(0, 80)
\t\t\tvar btn = Button.new()
\t\t\tbtn.text = "%s姓·%s氏（聘礼约%d石）" % [surname, clan, dowry_cost]
\t\t\tbtn.custom_minimum_size = Vector2(0, 34)
\t\t\tbtn.pressed.connect(_on_marry_propose.bind(surname, clan, dowry_cost, popup2))
\t\t\tvbox.add_child(btn)

\tvar cb = Button.new(); cb.text = "返回"; cb.pressed.connect(func(): popup2.queue_free(); _on_marry()); vbox.add_child(cb)
\tadd_child(popup2)

func _on_arranged_marriage(popup: CanvasLayer) -> void:
\t"""父母之命——父母挑选配偶，无需聘礼"""
\tpopup.queue_free()
\tvar char = GameState.current_character

\t# 检查父母是否在世
\tif not GameState.family_data.has("parents"):
\t\t_add_log("父母之命——可惜你的父母已不在世，只能靠自己了。")
\t\t_on_marry()
\t\treturn
\tvar parents = GameState.family_data.parents
\tvar father_alive = parents.father.get("is_alive", false)
\tvar mother_alive = parents.mother.get("is_alive", false)
\tif not father_alive and not mother_alive:
\t\t_add_log("父母之命——可惜你的父母已不在世，只能靠自己了。")
\t\t_on_marry()
\t\treturn

\t# 父母为你挑选配偶
\tvar eligible = CharacterManager.get_eligible_surnames(char)
\tif eligible.is_empty():
\t\t_add_log("议亲失败——没有合适的对象。")
\t\treturn
\tvar chosen_surname: String = eligible[randi_range(0, eligible.size() - 1)]
\tvar clans_map = {
\t\t"姬": ["周", "鲁", "晋", "卫", "郑", "燕"], "姜": ["吕", "齐", "许", "申"],
\t\t"姒": ["杞", "鄫", "褒"], "妫": ["陈", "田"], "嬴": ["秦", "赵", "徐"],
\t\t"姞": ["南燕", "密"], "妘": ["郧", "邬"], "姚": ["姚"],
\t}
\tvar clan_list = clans_map.get(chosen_surname, [chosen_surname])
\tvar chosen_clan: String = clan_list[randi_range(0, clan_list.size() - 1)]

\t# 父母操办，聘礼由父母出（不从玩家财产扣）
\t_add_log("👴 父母之命——父母为你定下了%s姓·%s氏的亲事，聘礼由家族承担。" % [chosen_surname, chosen_clan])

\t# 直接结婚（跳过骰子检定和财产检查）
\tvar marriage = CharacterManager.propose_marriage_parents(char, chosen_surname, chosen_clan)
\tif not marriage.success:
\t\t_add_log("议亲失败——" + marriage.message)
\t\treturn

\t_add_log("💒 " + marriage.message)
\t_do_family_separation()
\t_refresh_display()

func _do_family_separation() -> void:
\t"""婚后分家——独立门户"""
\tvar char = GameState.current_character
\tif char.get("_separated", false):
\t\treturn
\tchar["_separated"] = true

\t# 父母给一笔安家费
\tvar separation_gift := 20 + randi_range(0, 30)
\tCharacterManager.modify_wealth(separation_gift)
\t_add_log("🏠 婚后分家——你从父母家中独立门户。家族赠予 %d 石作为安家费。" % separation_gift)"""

content = content.replace(old1, new1, 1)

# === 2. Modify _on_marry_propose to trigger 分家 after success ===
# Find the pattern: after successful marriage log, before _refresh_display
old2 = """\t\t_add_log("💒 " + marriage0.message)
\t\t\t_refresh_display()
\t1:
\t\t# 成功——正常提亲
\t\tvar marriage1 = CharacterManager.propose_marriage(char, surname, clan, dowry)
\t\tif not marriage1.success:
\t\t\t_add_log("议亲失败——" + marriage1.message)
\t\t\treturn
\t\t_add_log("💒 " + marriage1.message)
\t\t_refresh_display()
\t2:
\t\t# 部分成功——对方犹豫，需要加20石聘礼
\t\tvar extra: int = dowry + 20
\t\t_add_log("议亲——%s姓·%s氏有些犹豫，要求增加聘礼至%d石……" % [surname, clan, extra])
\t\tif GameState.family_data.wealth < extra:
\t\t\t_add_log("议亲失败——聘礼不足。需要 %d 石，你只有 %d 石。" % [extra, GameState.family_data.wealth])
\t\t\treturn
\t\tvar marriage2 = CharacterManager.propose_marriage(char, surname, clan, extra)
\t\tif not marriage2.success:
\t\t\t_add_log("议亲失败——" + marriage2.message)
\t\t\treturn
\t\t_add_log("💒 " + marriage2.message)
\t\t_refresh_display()"""

assert old2 in content, "marry_propose success pattern not found"

new2 = """\t\t_add_log("💒 " + marriage0.message)
\t\t\t_do_family_separation()
\t\t\t_refresh_display()
\t1:
\t\t# 成功——正常提亲
\t\tvar marriage1 = CharacterManager.propose_marriage(char, surname, clan, dowry)
\t\tif not marriage1.success:
\t\t\t_add_log("议亲失败——" + marriage1.message)
\t\t\treturn
\t\t_add_log("💒 " + marriage1.message)
\t\t_do_family_separation()
\t\t_refresh_display()
\t2:
\t\t# 部分成功——对方犹豫，需要加20石聘礼
\t\tvar extra: int = dowry + 20
\t\t_add_log("议亲——%s姓·%s氏有些犹豫，要求增加聘礼至%d石……" % [surname, clan, extra])
\t\tif GameState.family_data.wealth < extra:
\t\t\t_add_log("议亲失败——聘礼不足。需要 %d 石，你只有 %d 石。" % [extra, GameState.family_data.wealth])
\t\t\treturn
\t\tvar marriage2 = CharacterManager.propose_marriage(char, surname, clan, extra)
\t\tif not marriage2.success:
\t\t\t_add_log("议亲失败——" + marriage2.message)
\t\t\treturn
\t\t_add_log("💒 " + marriage2.message)
\t\t_do_family_separation()
\t\t_refresh_display()"""

content = content.replace(old2, new2, 1)

# === 3. Modify _age_gate_buttons: ask_parents disabled after separation ===
old3 = """\tvar can_ask_parents = false
\tif GameState.family_data.has("parents"):
\t\tvar p = GameState.family_data.parents
\t\tvar fa = p.father.get("is_alive", false)
\t\tvar ma = p.mother.get("is_alive", false)
\t\tcan_ask_parents = (fa or ma) and p.get("family_wealth", 0) > 0 and age < 20"""

assert old3 in content, "can_ask_parents logic not found"

new3 = """\tvar can_ask_parents = false
\tvar is_separated = char.get("_separated", false)
\tif GameState.family_data.has("parents") and not is_separated:
\t\tvar p = GameState.family_data.parents
\t\tvar fa = p.father.get("is_alive", false)
\t\tvar ma = p.mother.get("is_alive", false)
\t\tcan_ask_parents = (fa or ma) and p.get("family_wealth", 0) > 0 and age < 20"""

content = content.replace(old3, new3, 1)

# === 4. Modify _on_ask_parents to check separation ===
old4 = """func _on_ask_parents() -> void:
\tif not _can_act("ask_parents"):
\t\t_add_log("本季已向父母要过钱，下季再来吧。")
\t\treturn
\tvar char = GameState.current_character
\tvar age = CharacterManager.get_character_age(char)
\tif age >= 20:
\t\t_add_log("你已经成年，不应再向父母伸手要钱。")
\t\treturn"""

assert old4 in content, "_on_ask_parents not found"

new4 = """func _on_ask_parents() -> void:
\tif not _can_act("ask_parents"):
\t\t_add_log("本季已向父母要过钱，下季再来吧。")
\t\treturn
\tvar char = GameState.current_character
\tif char.get("_separated", false):
\t\t_add_log("你已分家独立门户，不应再向父母伸手要钱。")
\t\treturn
\tvar age = CharacterManager.get_character_age(char)
\tif age >= 20:
\t\t_add_log("你已经成年，不应再向父母伸手要钱。")
\t\treturn"""

content = content.replace(old4, new4, 1)

with open(FILE, "w", encoding="utf-8") as f:
    f.write(content)

print("Done - added arranged marriage + family separation system")
