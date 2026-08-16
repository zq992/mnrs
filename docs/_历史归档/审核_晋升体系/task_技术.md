你是 Godot 4 游戏技术评审。

请先 Read 当前目录的 review_target.md，然后分两步：

【第一步：代码事实核对】到代码库 E:\技术资料\项目\mnrs 只 grep 清单文件（不遍历全树，10 分钟内）：
1. social_level 等级定义（奴隶→天子是否 6 级？在 game_state.gd 或 character_manager.gd）
2. 职业系统 PROFESSION_WORK_DATA / SHI_PROFESSIONS 现有职业（现 7 士职业是否属实）
3. 晋升函数 promote_character / can_promote / grant_promotion 是否存在
4. 是否有"奴隶/赎身/放良/殉葬/功绩/事功"相关现有代码或字段
5. official_merit（政绩）、military_merit（军功）字段是否存在

【第二步：技术可行性评估】以下改造的可实现性与风险（Godot 4.3 GDScript）：
- 职业分层 21 种 + 阶层绑定（士不得务农/无业）
- 晋升考核（民望倒置 + 技能 + 考核）
- 机缘跳级（随机事件 + 概率封顶）
- 奴隶赎身（放良文书）+ 殉葬（游戏结束）
- 功绩系统（军功/事功）

只审"技术可行性"一个维度。输出 P0（不可行或事实错误）/P1（高成本高风险）/P2（建议），每条标注【章节+原文+代码证据(文件:行号)+修改建议】。最后中文总结：核实几项、几处不符、几处技术风险、总体可行性判断。
