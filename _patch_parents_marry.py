#!/usr/bin/env python3
"""Add propose_marriage_parents() to character_manager.gd"""

FILE = r"E:\技术资料\项目\mnrs\scripts\core\character_manager.gd"

with open(FILE, "r", encoding="utf-8") as f:
    content = f.read()

old = """\treturn {
\t\t"success": true, "spouse": spouse, "dowry_paid": dowry, "bride_wealth": bride_wealth,
\t\t"message": "你与%s%s·%s氏结为夫妻！嫁妆 %d 石。" % [spouse_surname, spouse.name, spouse.clan, bride_wealth]
\t}

# ============================================================
# 子女系统
# ============================================================"""

assert old in content, "Insertion point for propose_marriage_parents not found"

new = """\treturn {
\t\t"success": true, "spouse": spouse, "dowry_paid": dowry, "bride_wealth": bride_wealth,
\t\t"message": "你与%s%s·%s氏结为夫妻！嫁妆 %d 石。" % [spouse_surname, spouse.name, spouse.clan, bride_wealth]
\t}

func propose_marriage_parents(character: Dictionary, spouse_surname: String, spouse_clan: String) -> Dictionary:
\t"""父母包办婚姻——无需聘礼，跳过财产检查"""
\tif is_married(character):
\t\treturn {"success": false, "message": "你已有配偶。西周礼法不允许多妻。"}
\tif spouse_surname == character.surname:
\t\treturn {"success": false, "message": "同姓不婚！%s姓与%s姓不可通婚。" % [spouse_surname, character.surname]}
\tvar spouse_age = max(16, character.age - randi_range(-3, 8))
\tvar spouse = generate_spouse(spouse_surname, spouse_clan, spouse_age)
\tvar bride_wealth = 20 + randi_range(10, 40)
\tCharacterManager.modify_wealth(bride_wealth)
\tcharacter.relationships.spouse = spouse
\tGameState.family_data.family_tree["spouse"] = spouse
\treturn {
\t\t"success": true, "spouse": spouse, "dowry_paid": 0, "bride_wealth": bride_wealth,
\t\t"message": "父母之命——你与%s%s·%s氏结为夫妻！嫁妆 %d 石。" % [spouse_surname, spouse.name, spouse.clan, bride_wealth]
\t}

# ============================================================
# 子女系统
# ============================================================"""

content = content.replace(old, new, 1)

with open(FILE, "w", encoding="utf-8") as f:
    f.write(content)

print("Done - added propose_marriage_parents() to character_manager.gd")
