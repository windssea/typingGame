class_name GameContent
extends RefCounted

static func lessons() -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/curriculum.json"))
	return parsed.lessons

static func modes() -> Array:
	return [
		{"id":"dojo", "name":"指尖发射站", "tag":"LEARN / 无压力", "description":"跟着小教练找到按键，\n点亮一圈进步能量。", "goal":"完成 18 个目标 · 无失败惩罚"},
		{"id":"bubbles", "name":"泡泡啵啵乐", "tag":"PLAY / 自由找键", "description":"选中漂浮泡泡，输入戳破它，\n收集一串彩色小水珠。", "goal":"自由选择目标 · 无时间压力"},
		{"id":"rain", "name":"流星拦截队", "tag":"REACT / 反应训练", "description":"锁定坠落流星，击键拦截！\n守住下方的能量防线。", "goal":"守住 90 秒 · 5 次失误机会"},
		{"id":"sprint", "name":"极速 60 秒", "tag":"SPRINT / 速度挑战", "description":"每个按键都是向前一步。\n保持准确，看速度表升起！", "goal":"60 秒连续输入 · 比拼准确与速度"},
		{"id":"castle", "name":"魔法城堡战", "tag":"DEFEND / 塔防战役", "description":"建造元素塔，强化魔法，\n迎战六波军团与统领。", "goal":"六波战役 · 三种塔 · 两场 Boss"},
		{"id":"balloons", "name":"气球蹦蹦节", "tag":"POP / 找键与反应", "description":"给气球充气，输入完成就爆破！\n看准金色奖励气球。", "goal":"优先处理高处目标 · 练习找键"},
		{"id":"aliens", "name":"星际闪电战", "tag":"SPACE / 输入与防御", "description":"逐键蓄能，完成输入发射激光。\n三连击恢复基地护盾。", "goal":"护盾与船体 · 连击补给"},
		{"id":"moles", "name":"地鼠敲敲乐", "tag":"WHACK / 定位与切换", "description":"地鼠钻出洞口，逐键举锤，\n输入完成，敲出小星星！", "goal":"训练漏掉不扣血 · 准确定位"},
		{"id":"racing", "name":"疾速拉力赛", "tag":"RACE / 稳定与速度", "description":"输入推进赛车，连击加速。\n挑战时抢在对手前冲线。", "goal":"训练自由完赛 · 挑战竞速"},
		{"id":"fighter", "name":"连击小拳王", "tag":"FIGHT / 连击与反应", "description":"逐键蓄势，完成输入打出重拳。\n打断对手蓄力，连击制胜。", "goal":"四次命中击倒对手 · 攻击打断"}
	]
