import os
os.chdir(r'E:\技术资料\项目\mnrs')
path = 'scripts/core/character_manager.gd'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

count = 0

# 1. Change can_promote() - Lv1-3 reputation only (no power)
old1 = '''func can_promote(character: Dictionary) -> bool:
\tvar current_level = character.social_level

\t# 天子之上不可再升
\tif current_level >= 6:
\t\treturn false

\t# 检查势力值 或 声望值（OR关系，任一满足即可）
\tvar power = character.derived.power
\tvar rep = character.derived.get("reputation", 0)
\tmatch current_level:
\t\t1: return power >= 15 or rep >= 40   # 奴隶→庶人
\t\t2: return power >= 30 or rep >= 70   # 庶人→士
\t\t3: return power >= 50 or rep >= 90   # 士→卿大夫
\t\t4: return power >= 70 or rep >= 120  # 卿大夫→诸侯
\t\t5: return power >= 85 or rep >= 150  # 诸侯→天子
\treturn false'''

new1 = '''func can_promote(character: Dictionary) -> bool:
\tvar current_level = character.social_level

\t# 天子之上不可再升
\tif current_level >= 6:
\t\treturn false

\tvar rep = character.derived.get("reputation", 0)
\tvar power = character.derived.power
\tmatch current_level:
\t\t1: return rep >= 40              # 奴隶→庶人：仅声望
\t\t2: return rep >= 70              # 庶人→士：仅声望
\t\t3: return rep >= 90              # 士→卿大夫：仅声望（还需官职）
\t\t4: return power >= 70 or rep >= 120  # 卿大夫→诸侯
\t\t5: return power >= 85 or rep >= 150  # 诸侯→天子
\treturn false'''

if old1 in content:
    content = content.replace(old1, new1, 1)
    count += 1
    print("1. can_promote() updated - Lv1-3 reputation only")
else:
    print("1. FAILED: can_promote anchor")

# 2. Change can_promote_by_reputation() to can_promote_to_qingdafu()
old2 = '''func can_promote_by_reputation(character: Dictionary) -> bool:
\t"""仅通过声望检查是否可以晋升"""
\tvar current_level = character.social_level
\tif current_level >= 6:
\t\treturn false
\tvar rep = character.derived.get("reputation", 0)
\tmatch current_level:
\t\t1: return rep >= 40
\t\t2: return rep >= 70
\t\t3: return rep >= 90
\t\t4: return rep >= 120
\t\t5: return rep >= 150
\treturn false'''

new2 = '''func can_promote_by_reputation(character: Dictionary) -> bool:
\t"""仅通过声望检查是否可以晋升"""
\tvar current_level = character.social_level
\tif current_level >= 6:
\t\treturn false
\tvar rep = character.derived.get("reputation", 0)
\tmatch current_level:
\t\t1: return rep >= 40
\t\t2: return rep >= 70
\t\t3: return rep >= 90
\t\t4: return rep >= 120
\t\t5: return rep >= 150
\treturn false

func can_promote_to_qingdafu(character: Dictionary) -> bool:
\t"""士→卿大夫：除了声望，还必须持有官职"""
\tif character.social_level != 3:
\t\treturn false
\tif character.derived.get("reputation", 0) < 90:
\t\treturn false
\tvar pos = character.get("official_position", "")
\treturn not pos.is_empty()'''

if old2 in content:
    content = content.replace(old2, new2, 1)
    count += 1
    print("2. can_promote_to_qingdafu() added")
else:
    print("2. FAILED: can_promote_by_reputation anchor")

# 3. Change promotion decay from fixed to percentage
old3 = '''\t# 晋升后衰减：新环境中你只是"小人物"
\tvar ambition_loss := 10 + randi_range(0, 15)  # -10~-25
\tvar rep_loss := 5 + randi_range(0, 10)        # -5~-15
\tcharacter.ambition = max(0, character.ambition - ambition_loss)
\tcharacter.reputation = max(0, character.reputation - rep_loss)
\tcharacter.derived.ambition = character.ambition
\tcharacter.derived.reputation = character.reputation
\t# 重新计算势力值（声望变了）
\tcharacter.derived.power = _calculate_power(character)

\tvar decay_msg := "\\n（晋升衰减：野心-%d，声望-%d）" % [ambition_loss, rep_loss]'''

new3 = '''\t# 晋升后衰减：百分比（新环境中你只是"小人物"）
\tvar ambition_pct := randf_range(0.20, 0.40)   # 减当前野心的20%-40%
\tvar rep_pct := randf_range(0.15, 0.30)        # 减当前声望的15%-30%
\tvar ambition_loss := int(ceil(character.ambition * ambition_pct))
\tvar rep_loss := int(ceil(character.reputation * rep_pct))
\tcharacter.ambition = max(0, character.ambition - ambition_loss)
\tcharacter.reputation = max(0, character.reputation - rep_loss)
\tcharacter.derived.ambition = character.ambition
\tcharacter.derived.reputation = character.reputation
\t# 重新计算势力值（声望变了）
\tcharacter.derived.power = _calculate_power(character)

\tvar decay_msg := "\\n（晋升衰减：野心-%.0f%%，声望-%.0f%%）" % [ambition_pct * 100, rep_pct * 100]'''

if old3 in content:
    content = content.replace(old3, new3, 1)
    count += 1
    print("3. Promotion decay changed to percentage")
else:
    print("3. FAILED: decay anchor")

# 4. Add official_position and fief fields to create_character()
old4 = '''\t"official_position": "",     # 官职——空表示无官职
\t"household_troops": 0,     # 当前私兵数量
\t"max_troops": 0,           # 最大带兵数（根据等级）'''

# Check if official_position already exists
if '"official_position"' in content:
    print("4. official_position already exists, adding fief field")
    old4 = '''\t"official_position": "",     # 官职——空表示无官职
\t"household_troops": 0,     # 当前私兵数量
\t"max_troops": 0,           # 最大带兵数（根据等级）'''
    new4 = '''\t"official_position": "",     # 官职——空表示无官职
\t"fief": "",                # 封地——诸侯才有
\t"household_troops": 0,     # 当前私兵数量
\t"max_troops": 0,           # 最大带兵数（根据等级）'''
else:
    print("4. Adding official_position + fief fields")
    old4 = '''\t"legitimacy": 0,
\t"household_troops": 0,     # 当前私兵数量
\t"max_troops": 0,           # 最大带兵数（根据等级）'''
    new4 = '''\t"legitimacy": 0,
\t"official_position": "",     # 官职——空表示无官职
\t"fief": "",                # 封地——诸侯才有
\t"household_troops": 0,     # 当前私兵数量
\t"max_troops": 0,           # 最大带兵数（根据等级）'''

if old4 in content:
    content = content.replace(old4, new4, 1)
    count += 1
    print("4. official_position + fief fields added")
else:
    print("4. FAILED: fields anchor")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"\nDone. {count}/4 changes applied to character_manager.gd.")
